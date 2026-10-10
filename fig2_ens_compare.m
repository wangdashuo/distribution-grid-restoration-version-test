function fig2_ens_compare(results, saveDir)
% FIG2_ENS_COMPARE  ENS & 加权 ENS 4 场景对比

    style_poster(); C = poster_colors();
    K = numel(results);
    shortNames = {'S1\n无任何指标','S2\n+重要度','S3\n+可靠性','S4\n+AI'};

    ens  = [results.ENS];
    ensW = [results.ENS_w];

    fig = figure('Position',[50 50 1400 550]);

    subplot(1,2,1);
    h = bar([ens(:), ensW(:)], 'grouped');
    h(1).FaceColor = [0.30 0.55 0.85];
    h(2).FaceColor = [0.85 0.40 0.30];
    set(gca,'XTickLabel', shortNames, 'FontSize',13);
    ylabel('ENS (MWh)','FontSize',14);
    title('失负荷量对比','FontSize',15);
    legend({'实际 ENS','加权 ENS'}, 'Location','northeast','FontSize',12);
    grid on;

    % 数字标
    for i = 1:K
        text(i-0.15, ens(i)+max(ens)*0.02, sprintf('%.3f',ens(i)), ...
             'HorizontalAlignment','center','FontSize',11,'FontWeight','bold');
        text(i+0.15, ensW(i)+max(ensW)*0.02, sprintf('%.3f',ensW(i)), ...
             'HorizontalAlignment','center','FontSize',11,'FontWeight','bold', ...
             'Color',[0.85 0.4 0.3]);
    end

    % 改进幅度
    subplot(1,2,2);
    impENS = (ens(1) - ens) / max(ens(1),1e-6) * 100;
    impW   = (ensW(1) - ensW) / max(ensW(1),1e-6) * 100;
    bar([impENS(:), impW(:)]);
    set(gca,'XTickLabel', shortNames, 'FontSize',13);
    ylabel('相对 S1 下降 (%)','FontSize',14);
    title('改进幅度','FontSize',15);
    legend({'实际 ENS','加权 ENS'}, 'Location','northwest','FontSize',12);
    grid on;

    sgtitle('4 种恢复策略的失负荷对比','FontSize',16,'FontWeight','bold');
    exportgraphics(fig, fullfile(saveDir,'fig2_ens_compare.png'), 'Resolution', 300);
end