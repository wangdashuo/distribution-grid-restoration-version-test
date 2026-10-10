function cfg = config()
% ===== 系统基准 =====
    cfg.baseMVA   = 10;
    cfg.baseKV    = 12.66;
    cfg.Vmin      = 0.94;
    cfg.Vmax      = 1.06;
    cfg.Pmax      = 0.60;
    cfg.T         = 4;         % 想更快可设 3
    cfg.dt        = 1;
    cfg.nCrew     = 2;

% ===== 目标权重 =====
    cfg.C_ENS     = 50;
    cfg.lambda_AI = 0.5;

% ===== 故障生成（仅多故障）=====
    cfg.maxFaults = 4;
    cfg.minFaults = 2;
    cfg.nScenarios= 10;         % ★ 从 30 降到 10（每个需解 MILP）

% ===== AI 训练 =====
    cfg.useFastLabel = false;   % ★ 默认走 MILP 真实标签
                                %   设 true 则切到启发式（对照/调试用）

    cfg.seed      = 42;
end