function fault = generate_fault_scenario(sys, cfg)
% 生成连锁故障场景（台风/沙尘暴导致的大范围停电）
% ★ 只生成 2 条及以上故障，不做单设备故障

    nB    = sys.nBranch;
    cand  = find(~sys.isTie);
    nC    = numel(cand);

    k = randi([cfg.minFaults, cfg.maxFaults]);
    k = min(k, nC);

    idx   = cand(randperm(nC, k));
    fault = false(nB, 1);
    fault(idx) = true;
end