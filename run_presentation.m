function run_presentation(results, sys, cfg, testFault, wAI, model)
% RUN_PRESENTATION  统一入口：加载 results.mat → 出所有 Poster 图
%
% 用法（两种）:
%   >> run_presentation                              % 从 results.mat 读
%   >> run_presentation(results,sys,cfg,testFault,wAI,model)  % 从工作区传

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(projectRoot));

    % ---------- 获取数据 ----------
    if nargin == 0
        matFile = fullfile(projectRoot, 'results.mat');
        if ~exist(matFile, 'file')
            error(['未找到 %s\n' ...
                   '请先运行 main.m 生成 results.mat，' ...
                   '或者直接把工作区的变量传进来：\n' ...
                   '  >> run_presentation(results,sys,cfg,testFault,wAI,model)'], ...
                   matFile);
        end
        load(matFile, 'results', 'sys', 'cfg', 'testFault', 'wAI', 'model');
    elseif nargin < 6
        error(['输入参数不足。请用下列两种方式之一：\n' ...
               '  1) run_presentation                              (从 results.mat 读)\n' ...
               '  2) run_presentation(results,sys,cfg,testFault,wAI,model)']);
    end

    % ---------- 输出目录 ----------
    saveDir = fullfile(projectRoot, 'presentation', 'output');
    if ~exist(saveDir, 'dir'), mkdir(saveDir); end
    fprintf('\n输出目录: %s\n', saveDir);

    % ---------- 依次出图 ----------
    fprintf('\n[1/6] 系统 + 故障拓扑\n');   fig1_network(sys, testFault, saveDir);
    fprintf('[2/6] ENS 对比\n');            fig2_ens_compare(results, saveDir);
    fprintf('[3/6] 关键负荷恢复\n');        fig3_critical_recovery(results, sys, cfg, saveDir);
    fprintf('[4/6] 经济性对比\n');          fig4_economic_salvage(results, sys, cfg, saveDir);
    fprintf('[5/6] 抢修甘特图\n');          fig5_crew_timeline(results, sys, cfg, saveDir);
    fprintf('[6/6] 汇总表\n');              fig6_summary_table(results, sys, cfg, saveDir);

    fprintf('\n全部完成！所有图片保存在:\n  %s\n', saveDir);
end