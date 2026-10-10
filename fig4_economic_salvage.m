function fig4_economic_salvage(results, sys, cfg, saveDir)
% FIG4_ECONOMIC_SALVAGE
% 经济性：与"什么都不做（全部失负荷）"相比，各策略挽回多少电量、
% 折合多少钱（$），以及挽回关键负荷（DC/医院）分别贡献多少。

    style_poster();
    K = numel(results);
    shortNames = {'S1','S2','S3','S4'};

    % ---- 全部失负荷（基准）----
    totalP_kW = sum(sys.Pload_kW(2:end));            % kW
    totalMWh  = totalP_kW * cfg.dt * cfg.T / 1000;   % 全部失电时总电量 MWh
    totalUSD  = totalMWh * 1000 * cfg.C_ENS;         % 全部失电损失 $

    % ---- 各场景实际损失 ----
    ENS_MWh = [results.ENS];
    lossUSD = ENS_MWh * 1000 * cfg.C_ENS;

    % ---- 各场景挽回 ----
    salvage_MWh = totalMWh - ENS_MWh;
    salvage_USD = totalUSD - lossUSD;
    salvage_pct = salvage_MWh / totalMWh * 100;

    % ---- 图 ----
    fig = figure('Position',[50 50 1500 550]);

    % 左：挽回电量
    subplot(1,2,1);
    h = bar(salvage_MWh, 'FaceColor', [0.20 0.70 0.35], 'EdgeColor','k');
    set(gca,'XTickLabel', shortNames, 'FontSize',13);
    ylabel('挽回用电量 (MWh)','FontSize',14);
    title('与"不修复"相比挽回的用电量','FontSize',15);
    for k = 1:K
        text(k, salvage_MWh(k)+max(salvage_MWh)*0.02, ...
             sprintf('%.2f MWh\n(%.1f%%)', salvage_MWh(k), salvage_pct(k)), ...
             'HorizontalAlignment','center','FontSize',11,'FontWeight','bold');
    end
    grid on; ylim([0 max(salvage_MWh)*1.15]);

    % 右：挽回金额
    subplot(1,2,2);
    h = bar(salvage_USD/1000, 'FaceColor',[0.95 0.55 0.10],'EdgeColor','k');
    set(gca,'XTickLabel', shortNames, 'FontSize',13);
    ylabel('挽回经济损失 (千美元)','FontSize',14);
    title(sprintf('折合经济损失（电价 %.0f $/MWh）', cfg.C_ENS),'FontSize',15);
    for k = 1:K
        text(k, salvage_USD(k)/1000 + max(salvage_USD)*1e-3*0.02, ...
             sprintf('%.1f k$', salvage_USD(k)/1000), ...
             'HorizontalAlignment','center','FontSize',11,'FontWeight','bold');
    end
    grid on;

    sgtitle('恢复策略的经济效益','FontSize',16,'FontWeight','bold');
    exportgraphics(fig, fullfile(saveDir,'fig4_economic_salvage.png'), 'Resolution', 300);

    % ---- 打印明细 ----
    fprintf('\n========= 经济性对比 =========\n');
    fprintf('全部失负荷基准: %.2f MWh | %.1f k$\n', totalMWh, totalUSD/1000);
    fprintf('%-8s | %10s | %14s | %10s\n','场景','挽回MWh','挽回千$','挽回%%');
    for k = 1:K
        fprintf('%-8s | %10.2f | %14.1f | %9.1f%%\n', ...
                shortNames{k}, salvage_MWh(k), salvage_USD(k)/1000, salvage_pct(k));
    end
end