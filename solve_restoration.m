function res = solve_restoration(fault, wAI, sys, cfg, scene)
% SOLVE_RESTORATION 多时段配电网恢复优化（含联络开关重构）
%
% scene 结构体字段（缺省 true/true/false）:
%   .useReliability   是否启用可靠性指标 wRel
%   .useImportance    是否启用负荷重要度 wImp
%   .useAI            是否启用 AI 优先级奖励项

    if nargin < 5 || isempty(scene), scene = struct(); end
    if ~isfield(scene,'useReliability'), scene.useReliability = true;  end
    if ~isfield(scene,'useImportance'),  scene.useImportance  = true;  end
    if ~isfield(scene,'useAI'),          scene.useAI          = false; end

    nB   = sys.nBranch;   nN = sys.nNode;   T  = cfg.T;
    isTie = sys.isTie;    root = sys.root;
    baseMVA = cfg.baseMVA;
    Zbase   = cfg.baseKV^2 / baseMVA;

    Pload = sys.Pload_kW   / 1000 / baseMVA;
    Qload = sys.Qload_kVar / 1000 / baseMVA;
    Rpu   = sys.R / Zbase;   Xpu = sys.X / Zbase;

    %% -------- 组合节点权重 --------
    wNode = ones(nN, 1);
    if scene.useImportance,  wNode = wNode .* sys.wImp;  end
    if scene.useReliability, wNode = wNode .* sys.wRel;  end

    %% -------- 变量 --------
    y     = binvar(nB, T);
    s     = binvar(nB, T);
    d     = binvar(nB, T);
    alpha = sdpvar(nN, T);
    P     = sdpvar(nB, T);
    Q     = sdpvar(nB, T);
    v     = sdpvar(nN, T);

    C = [];

    %% -------- 修复逻辑 --------
    for e = 1:nB
        if isTie(e)
            C = [C, s(e,:) == 0];
        elseif fault(e)
            C = [C, sum(s(e,:)) <= 1];
            for t = 1:T
                C = [C, y(e,t) == sum(s(e,1:t))];
            end
        else
            C = [C, s(e,:) == 0];
        end
    end

    %% -------- 班组数量 --------
    for t = 1:T
        C = [C, sum(s(:,t)) <= cfg.nCrew];
    end

    %% -------- 方向指示 --------
    for t = 1:T
        for e = 1:nB
            C = [C, d(e,t) <= y(e,t)];
        end
    end

    %% -------- 拓扑约束（父节点计数） --------
    for t = 1:T
        for j = 1:nN
            if j == root
                C = [C, alpha(j,t) == 0];
                continue;
            end
            pc = 0;
            for e = 1:nB
                if sys.from(e) == j
                    pc = pc + (y(e,t) - d(e,t));
                end
                if sys.to(e) == j
                    pc = pc + d(e,t);
                end
            end
            C = [C, pc == 1 - alpha(j,t)];
        end
    end

    %% -------- alpha 方向一致性 --------
    for t = 1:T
        for e = 1:nB
            i = sys.from(e); j = sys.to(e);
            C = [C, alpha(i,t) <= 1 - d(e,t)];
            C = [C, alpha(j,t) <= (1 - y(e,t)) + d(e,t)];
        end
    end

    %% -------- 电压约束（失负荷节点松弛） --------
    Vmin2 = cfg.Vmin^2;  Vmax2 = cfg.Vmax^2;
    Mv = 1.0;  Mbig = 2.0;
    for t = 1:T
        C = [C, v(root,t) == 1];
        for j = 2:nN
            C = [C, v(j,t) <= Vmax2 + Mv * alpha(j,t)];
            C = [C, v(j,t) >= Vmin2 - Mv * alpha(j,t)];
        end
        for e = 1:nB
            i = sys.from(e); j = sys.to(e);
            expr = v(j,t) - v(i,t) + 2*(Rpu(e)*P(e,t) + Xpu(e)*Q(e,t));
            C = [C,  expr <=  Mbig*(1 - y(e,t))];
            C = [C,  expr >= -Mbig*(1 - y(e,t))];
        end
    end

    %% -------- 节点功率平衡 --------
    for t = 1:T
        for j = 2:nN
            netP = 0; netQ = 0;
            for e = 1:nB
                if sys.to(e) == j
                    netP = netP + P(e,t); netQ = netQ + Q(e,t);
                end
                if sys.from(e) == j
                    netP = netP - P(e,t); netQ = netQ - Q(e,t);
                end
            end
            C = [C, netP == Pload(j) * (1 - alpha(j,t))];
            C = [C, netQ == Qload(j) * (1 - alpha(j,t))];
        end
    end

    %% -------- 线路过载 --------
    Pmax = cfg.Pmax;
    for t = 1:T
        for e = 1:nB
            C = [C, -Pmax*y(e,t) <= P(e,t) <= Pmax*y(e,t)];
            C = [C, -Pmax*y(e,t) <= Q(e,t) <= Pmax*y(e,t)];
        end
    end

    %% -------- 目标函数 --------
    obj = 0;
    for t = 1:T
        for j = 2:nN
            obj = obj + cfg.C_ENS * wNode(j) * Pload(j) * baseMVA * alpha(j,t) * cfg.dt;
        end
    end
    if scene.useAI
        for e = 1:nB
            for t = 1:T
                obj = obj + cfg.lambda_AI * wAI(e) * t * s(e,t);
            end
        end
    end

    %% -------- 求解 --------
    opts = sdpsettings('solver','intlinprog','verbose',0, ...
                       'intlinprog.MaxTime', 300);
    sol = optimize(C, obj, opts);
    if sol.problem ~= 0
        fprintf('    [!] 求解状态: %s\n', sol.info);
    end

    res.alpha = value(alpha);
    res.y = value(y);  res.s = value(s);  res.d = value(d);
    res.sol = sol;  res.scene = scene;

    if isempty(res.alpha) || all(isnan(res.alpha(:)))
        res.ENS = NaN;  res.ENS_w = NaN;  res.obj = NaN;
        warning('求解失败');
        return;
    end

    ens = 0; ens_w = 0;
    for t = 1:T
        for j = 2:nN
            ens   = ens   + Pload(j) * baseMVA * res.alpha(j,t) * cfg.dt;
            ens_w = ens_w + sys.wImp(j) * Pload(j) * baseMVA * res.alpha(j,t) * cfg.dt;
        end
    end
    res.ENS   = ens;
    res.ENS_w = ens_w;
    res.obj   = value(obj);
end