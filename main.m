%% ============ 多时段配电网恢复 + AI 抢修优先级 ============
clear; clc; close all;
addpath(genpath(fileparts(mfilename('fullpath'))));

cfg = config();
sys = ieee69bus();
rng(cfg.seed);

fprintf('\n===== 阶段1: 生成 AI 训练数据（MILP 求解）=====\n');
[X, Y] = generate_training_data(sys, cfg);

fprintf('\n===== 阶段2: 训练抢修优先级模型 =====\n');
model = train_priority_model(X, Y);

fprintf('\n===== 阶段3: 生成测试场景 =====\n');
testFault = generate_fault_scenario(sys, cfg);
fprintf('  测试故障线路: %s\n', mat2str(find(testFault)'));

wAI = predict_priority(model, testFault, sys, cfg);

%% 4 场景对比
scenes = {
    'S1: 无可靠性 无重要度 无AI', false, false, false;
    'S2: 无可靠性 有重要度 无AI', false, true,  false;
    'S3: 有可靠性 有重要度 无AI', true,  true,  false;
    'S4: 有可靠性 有重要度 +AI',  true,  true,  true;
};

results = struct([]);
for k = 1:size(scenes,1)
    fprintf('\n  [求解] %s ...\n', scenes{k,1});
    sc.useReliability = scenes{k,2};
    sc.useImportance  = scenes{k,3};
    sc.useAI          = scenes{k,4};
    t1 = tic;
    r  = solve_restoration(testFault, wAI, sys, cfg, sc);
    fprintf('    用时 %.2f 秒 | ENS=%.4f | 加权ENS=%.4f\n', ...
            toc(t1), r.ENS, r.ENS_w);
    r.name = scenes{k,1};  r.wAI = wAI;  r.scene = sc;
    if k == 1, results = r; else, results(k) = r; end %#ok<SAGROW>
end

%% ★ 保存结果，交给 presentation 层处理
save('results.mat', 'results', 'sys', 'cfg', 'testFault', 'wAI', 'model');
fprintf('\n计算完成，结果已保存到 results.mat\n');
fprintf('展示请运行: presentation/run_presentation\n');