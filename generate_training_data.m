function [X, Y] = generate_training_data(sys, cfg)
% 生成 AI 训练数据
% ★ 路线：随机多故障 → solve_restoration(MILP) → 从最优解提取优先级标签
%
% cfg.nScenarios    训练场景数（推荐 8~15）
% cfg.useFastLabel  true=启发式(仅用于对照，快但粗)  false=MILP(默认，真实)

    t0 = tic;
    [paths, downstream] = build_topology(sys);
    nB = sys.nBranch;

    if cfg.useFastLabel
        % ========== 快速启发式（对照用，默认关闭） ==========
        base = 0;
        for e = 1:nB
            if sys.isTie(e), continue; end
            ds = downstream{e};
            if ~isempty(ds)
                base = max(base, sum(sys.wImp(ds) .* sys.Pload_kW(ds)));
            end
        end
        base = max(base, 1e-6);

        X = []; Y = [];
        for it = 1:cfg.nScenarios
            fault = generate_fault_scenario(sys, cfg);
            for e = find(fault)'
                f = extract_features(e, sys, paths, downstream);
                ds = downstream{e};
                if isempty(ds)
                    prio = 0;
                else
                    prio = sum(sys.wImp(ds) .* sys.Pload_kW(ds)) / base;
                end
                X = [X; f]; Y = [Y; prio]; %#ok<AGROW>
            end
        end
        fprintf('  [AI数据·启发式] 场景=%d, 样本=%d, 用时=%.2fs\n', ...
                cfg.nScenarios, size(X,1), toc(t0));
        return;
    end

    % ========== MILP 生成真实标签 ==========
    % 用一个"物理上最合理"的场景来求解：可靠性+重要度，无 AI
    sc = struct('useReliability', true, ...
                'useImportance',  true, ...
                'useAI',          false);

    % 预先批量生成故障场景（便于 parfor 使用）
    faults = cell(cfg.nScenarios, 1);
    for it = 1:cfg.nScenarios
        faults{it} = generate_fault_scenario(sys, cfg);
    end

    % ---- 求解每个场景（尝试 parfor，无 Parallel Toolbox 则回退）----
    sols = cell(cfg.nScenarios, 1);
    try
        parfor it = 1:cfg.nScenarios
            sols{it} = solve_restoration(faults{it}, zeros(nB,1), ...
                                         sys, cfg, sc);
        end
        fprintf('  [AI数据] 使用 parfor 并行求解\n');
    catch ME
        fprintf('  [AI数据] parfor 不可用 (%s)，改用串行\n', ME.identifier);
        for it = 1:cfg.nScenarios
            fprintf('    场景 %2d/%d ...', it, cfg.nScenarios);
            sols{it} = solve_restoration(faults{it}, zeros(nB,1), ...
                                         sys, cfg, sc);
            fprintf(' ENS=%.4f\n', sols{it}.ENS);
        end
    end

    % ---- 从解集里提取 (feature, label) ----
    X = []; Y = [];
    for it = 1:cfg.nScenarios
        r = sols{it};
        if ~isfield(r,'alpha') || isempty(r.alpha) || isnan(r.ENS)
            fprintf('    场景 %d 求解失败，跳过\n', it);
            continue;
        end
        fault = faults{it};

        for e = find(fault)'
            f = extract_features(e, sys, paths, downstream);

            tFix = find(r.s(e,:) > 0.5, 1);

            if isempty(tFix)
                % 未修复：
                %  - 下游完全无负荷 → 无价值
                %  - 下游有负荷 → 班组不够，属于"次优先"
                ds = downstream{e};
                if isempty(ds) || sum(sys.Pload_kW(ds)) < 1
                    prio = 0;
                else
                    prio = 0.1;
                end
            else
                % 修复时段 → 越早分越高，归一化到 [0,1]
                prio = (cfg.T - tFix + 1) / cfg.T;
            end

            X = [X; f]; Y = [Y; prio]; %#ok<AGROW>
        end
    end

    fprintf('  [AI数据·MILP] 场景=%d, 样本=%d, 用时=%.2fs\n', ...
            cfg.nScenarios, size(X,1), toc(t0));
end