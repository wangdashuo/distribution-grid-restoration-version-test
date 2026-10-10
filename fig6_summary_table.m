function fig6_summary_table(results, sys, cfg, saveDir)
% FIG6_SUMMARY_TABLE  汇总表（出图，非命令行）

    style_poster();
    K = numel(results);

    totalMWh = sum(sys.Pload_kW(2:end)) * cfg.dt * cfg.T / 1000;

    names    = cell(K,1);
    ens      = zeros(K,1);
    ensW     = zeros(K,1);
    salvage  = zeros(K,1);
    salvageUSD = zeros(K,1);
    dcT      = zeros(K,1);
    hosT     = zeros(K,1);

    dcIdx  = find(strcmp(sys.nodeType,'数据中心'));
    hosIdx = find(strcmp(sys.nodeType,'医院'));

    for k = 1:K
        names{k} = results(k).name;
        ens(k)   = results(k).ENS;
        ensW(k)  = results(k).ENS_w;
        salvage(k)    = totalMWh - ens(k);
        salvageUSD(k) = salvage(k)*1000*cfg.C_ENS;

        a = results(k).alpha;
        dcR  = mean(a(dcIdx, :), 1);
        hosR = mean(a(hosIdx,:), 1);
        dcT(k)  = firstRec(dcR);
        hosT(k) = firstRec(hosR);
    end

    % 用 uitable 更方便
    fig = figure('Position',[50 50 1400 400]); axis off;
    data = [ens, ensW, salvage, salvageUSD/1000, dcT, hosT];
    colNames = {'ENS(MWh)','加权ENS(MWh)','挽回(MWh)','挽回(千$)','DC恢复(时段)','医院恢复(时段)'};
    t = uitable(fig, 'Data',data, 'ColumnName',colNames, 'RowName',names, ...
                'Position',[20 40 1360 320], 'FontSize',12, ...
                'ColumnWidth',{130,140,120,120,140,150});
    title('4 种策略综合对比表','FontSize',16,'FontWeight','bold');

    exportgraphics(fig, fullfile(saveDir,'fig6_summary_table.png'), 'Resolution', 300);
end

function t0 = firstRec(series)
    idx = find(series < 1e-3, 1);
    if isempty(idx), t0 = NaN; else, t0 = idx; end
end