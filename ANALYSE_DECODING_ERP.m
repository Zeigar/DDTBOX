function analyse_decoding_erp(ANALYSIS)
%
% This is the master script for group-level analysis of EEG decoding
% results.
%
%
% Inputs:
%
%   ANALYSIS structure containing information about filepaths of decoding
%   results files and group-level analysis parameters. Each member of the
%   structure is explained in the DDTBOX wiki or in the example
%   configuration script EXAMPLE_analyse_decoding_results
%
%
% Optional Keyword Inputs:
%
%
% Outputs:
%
%  
% Usage:            analyse_decoding_erp(ANALYSIS)
%
%
% Copyright (c) 2013-2016 Stefan Bode and contributors
% 
% This file is part of DDTBOX.
%
% DDTBOX is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.


%% GENERAL PARAMETERS AND GLOBAL VARIABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%__________________________________________________________________________

% define which subjects enter the second-level analysis
ANALYSIS.nsbj = size(ANALYSIS.sbjs_todo,2);
ANALYSIS.sbjs = ANALYSIS.sbjs_todo;

% Determine file labels based on SVM backend used
if ANALYSIS.analysis_mode == 1 
    ANALYSIS.analysis_mode_label='SVM_LIBSVM';
elseif ANALYSIS.analysis_mode == 2 
    ANALYSIS.analysis_mode_label='SVM_LIBLIN';
elseif ANALYSIS.analysis_mode == 3
    ANALYSIS.analysis_mode_label='SVR_LIBSVM';
end
    
fprintf('Group-level statistics will now be computed and displayed. \n'); 

%% OPEN FILES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%__________________________________________________________________________

for s = 1:ANALYSIS.nsbj
    
    %% open subject data
    sbj = ANALYSIS.sbjs(s);
        
    % open subject's decoding results       
    if size(ANALYSIS.dcg_todo, 2) == 1
        
        fprintf('Loading results for subject %d in DCG %s.\n',sbj,ANALYSIS.dcg_labels{ANALYSIS.dcg_todo});
        
        open_name = [(ANALYSIS.output_dir) ANALYSIS.study_name '_SBJ' num2str(sbj) '_win' num2str(ANALYSIS.window_width_ms) '_steps' num2str(ANALYSIS.step_width_ms)...
            '_av' num2str(ANALYSIS.avmode) '_st' num2str(ANALYSIS.stmode) '_' ANALYSIS.analysis_mode_label '_DCG' ANALYSIS.dcg_labels{ANALYSIS.dcg_todo} '.mat'];

    elseif size(ANALYSIS.dcg_todo,2) == 2
        
        fprintf('Loading results for subject %d for cross decoding DCG %s => DCG %s.\n',sbj,ANALYSIS.dcg_labels{ANALYSIS.dcg_todo(1)},ANALYSIS.dcg_labels{ANALYSIS.dcg_todo(2)});
        
        open_name=[(ANALYSIS.output_dir) ANALYSIS.study_name '_SBJ' num2str(sbj) '_win' num2str(ANALYSIS.window_width_ms) '_steps' num2str(ANALYSIS.step_width_ms)...
            '_av' num2str(ANALYSIS.avmode) '_st' num2str(ANALYSIS.stmode) '_' ANALYSIS.analysis_mode_label '_DCG' ANALYSIS.dcg_labels{ANALYSIS.dcg_todo(1)}...
            'toDCG' ANALYSIS.dcg_labels{ANALYSIS.dcg_todo(2)} '.mat'];
    end   
   
    load(open_name);
    fprintf('Done.\n');
    
    ANALYSIS.pointzero=ANALYSIS.pointzero;
        
    %% fill in parameters and extract results 
    %______________________________________________________________________
    %
    % RESULTS contains averaged results:
    % RESULTS.subj_acc(analysis/channel,time-step) 
    % RESULTS.subj_perm_acc(analysis/channel,time-step) 
    % RESULTS contains raw results:
    % RESULTS.prediction_accuracy{analysis/channel}(time-step,cross-val_step,rep_step)
    % RESULTS.perm_prediction_accuracy{analysis/channel}(time-step,cross-val_step,rep_step)
    %
    % this section adds group results to ANALYSIS:
    % ANALYSIS.RES.all_subj_acc(subject,analysis/channel,time_step(fist_step:last_step))
    % ANALYSIS.RES.all_subj_perm_acc(subject,analysis/channel,time_step(fist_step:last_step))
    % ANALYSIS.RES.all_subj_perm_acc_reps(subject,analysis/channel,time_step(fist_step:last_step),cross-val_step,rep_step)
    
    % Define missing parameters using the first subject's dataset
    %______________________________________________________________________
    if s == 1 
        
        % ask for the specific time steps to analyse
        if ANALYSIS.avmode == 1 || ANALYSIS.avmode == 1 % DF NOTE: Is the second IF statement supposed to specify a different value?
    
            fprintf('\n');
            fprintf('You have %d time-steps in your RESULTS. Each time-step represents a %d ms time-window. \n',size(RESULTS.subj_acc,2), cfg.window_width_ms);
            ANALYSIS.firststep = 1;
            ANALYSIS.laststep = input('Enter the number of the last time-window you want to analyse: ');

        end
    
        % shift everything back by step-width, as first bin gets label=0ms
        ANALYSIS.firststepms = (ANALYSIS.firststep * cfg.step_width_ms) - cfg.step_width_ms;
        ANALYSIS.laststepms = (ANALYSIS.laststep * cfg.step_width_ms) - cfg.step_width_ms;

        % create matrix for data indexing
        ANALYSIS.data(1,:) = 1:size(RESULTS.subj_acc,2); % for XTick
        ANALYSIS.data(2,:) = 0:cfg.step_width_ms:( (size(RESULTS.subj_acc,2) - 1) * cfg.step_width_ms); % for XLabel
        ptz = find(ANALYSIS.data(2,:) == ANALYSIS.pointzero); % find data with PointZero
        ANALYSIS.data(3,ptz) = 1; clear ptz; % for line location in plot

        % copy parameters from the config file
        ANALYSIS.step_width = cfg.step_width;
        ANALYSIS.window_width = cfg.window_width;
        ANALYSIS.sampling_rate = cfg.sampling_rate;
        ANALYSIS.feat_weights_mode = cfg.feat_weights_mode;
        
        ANALYSIS.nchannels = ANALYSIS.nchannels;
                
        ANALYSIS.channellocs = ANALYSIS.channellocs;
        ANALYSIS.channel_names_file = ANALYSIS.channel_names_file;     
                
        % extract Tick/Labels for x-axis
        for datastep = 1:ANALYSIS.laststep
            ANALYSIS.xaxis_scale(1,datastep) = ANALYSIS.data(1,datastep);
            ANALYSIS.xaxis_scale(2,datastep) = ANALYSIS.data(2,datastep);
            ANALYSIS.xaxis_scale(3,datastep) = ANALYSIS.data(3,datastep);
        end
        
        % Define chance level for statistical analyses based on the
        % analysis type
        if cfg.analysis_mode == 1 || cfg.analysis_mode == 2
            ANALYSIS.chancelevel = ( 100 / size(ANALYSIS.dcg{ANALYSIS.dcg_todo(1)},2) );
        elseif cfg.analysis_mode == 3 || cfg.analysis_mode == 4
            ANALYSIS.chancelevel = 0;
        end
        
        % Define channels to be used for group-analyses
        if ANALYSIS.allchan == 1

            % use all channels (default for spatial / spatial-temporal)
            ANALYSIS.allna = size(RESULTS.subj_acc,1);

        elseif ANALYSIS.allchan ~= 1

            % use specified number of channels
            ANALYSIS.allna = size(ANALYSIS.relchan,2);

        end
        
        % get label for DCG
        if size(ANALYSIS.dcg_todo,2) == 1
            ANALYSIS.DCG = ANALYSIS.dcg_labels{ANALYSIS.dcg_todo};
        elseif size(ANALYSIS.dcg_todo,2) == 2
            ANALYSIS.DCG{1} = ANALYSIS.dcg_labels{ANALYSIS.dcg_todo(1)};
            ANALYSIS.DCG{2} = ANALYSIS.dcg_labels{ANALYSIS.dcg_todo(2)};
        end
                
    end % of if s == 1 statement
    
    %% extract results data from specified time-steps / channels
    %______________________________________________________________________
    
    for na = 1:ANALYSIS.allna
        
        % Extract classifier and permutation test accuracies
        ANALYSIS.RES.all_subj_acc(s,na,ANALYSIS.firststep:ANALYSIS.laststep) = RESULTS.subj_acc(na,ANALYSIS.firststep:ANALYSIS.laststep);
        ANALYSIS.RES.all_subj_perm_acc(s,na,ANALYSIS.firststep:ANALYSIS.laststep) = RESULTS.subj_perm_acc(na,ANALYSIS.firststep:ANALYSIS.laststep);
            
        % needed if one wants to test against distribution of randomly
        % drawn permutation results (higher variance, stricter testing)
        ANALYSIS.RES.all_subj_perm_acc_reps(s,na,ANALYSIS.firststep:ANALYSIS.laststep,:,:) = RESULTS.perm_prediction_accuracy{na}(ANALYSIS.firststep:ANALYSIS.laststep,:,:);
            
    end
    %______________________________________________________________________
    
    % Extract feature weights
    if ANALYSIS.fw.do == 1 % If chosen to extract feature weights
        if ~isempty(RESULTS.feature_weights)
            ANALYSIS.RES.feature_weights{s} = RESULTS.feature_weights{1};
            ANALYSIS.RES.feature_weights_corrected{s} = RESULTS.feature_weights_corrected{1};
        end
    end % of if fw.do
    clear RESULTS;
    clear cfg;
    
end % of for n = 1:ANALYSIS.nsbj loop

fprintf('All data from all subjects loaded.\n');

%% AVERAGE DATA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%__________________________________________________________________________

% Calculate average accuracy & standard error across subjects
M(:,:) = mean(ANALYSIS.RES.all_subj_acc,1);
ANALYSIS.RES.mean_subj_acc(:,:) = M'; clear M;

if ANALYSIS.plot_robust == 1 % If plotting trimmed mean for group-level stats
    % Calculate and store the trimmed mean of subject accuracies
    trimmed_M(:,:) = trimmean(ANALYSIS.RES.all_subj_acc, ANALYSIS.plot_robust_trimming, 1);
    ANALYSIS.RES.trimmean_subj_acc(:,:) = trimmed_M'; clear trimmed_M;
    
elseif ANALYSIS.plot_robust == 2 % If plotting median for group-level stats
    
    median_M(:,:) = median(ANALYSIS.RES.all_subj_acc, 1);
    ANALYSIS.RES.median_subj_acc(:,:) = median_M'; clear median_M;
    
end % of if ANALYSIS.plot_robust

SE(:,:) = (std(ANALYSIS.RES.all_subj_acc,1))/(sqrt(ANALYSIS.nsbj));
ANALYSIS.RES.se_subj_acc(:,:) = SE'; clear SE;

if ANALYSIS.permstats == 2
    
    % OPTION 1: Use average results from random-labels test
    % Calculate average accuracy & standard error across subjects for permutation results
    M(:,:) = mean(ANALYSIS.RES.all_subj_perm_acc,1);
    ANALYSIS.RES.mean_subj_perm_acc(:,:) = M'; clear M;
    
    if ANALYSIS.plot_robust == 1 % If plotting trimmed mean for group-level stats
    % Calculate and store the trimmed mean of subject accuracies
        trimmed_M(:,:) = trimmean(ANALYSIS.RES.all_subj_perm_acc, ANALYSIS.plot_robust_trimming, 1);
        ANALYSIS.RES.trimmean_subj_perm_acc(:,:) = trimmed_M'; clear trimmed_M;
        
    elseif ANALYSIS.plot_robust == 2 % If plotting median for group-level stats
        
        median_M(:,:) = median(ANALYSIS.RES.all_subj_perm_acc, 1);
        ANALYSIS.RES.median_subj_perm_acc(:,:) = median_M'; clear median_M;
        
    end % of if ANALYSIS.plot_robust
    
    SE(:,:) = (std(ANALYSIS.RES.all_subj_perm_acc,1)) / (sqrt(ANALYSIS.nsbj));
    ANALYSIS.RES.se_subj_perm_acc(:,:) = SE'; clear SE;

    % OPTION 2: draw values from random-labels test
    % average permutation results across cross-validation steps, but draw later 
    % one for each participant for statistical testing!
    for subj = 1:ANALYSIS.nsbj
        for ana = 1:ANALYSIS.allna
            for step = 1:ANALYSIS.laststep
                
                temp(:,:) = ANALYSIS.RES.all_subj_perm_acc_reps(subj,ana,step,:,:);
                mtemp = mean(temp,1);
                ANALYSIS.RES.all_subj_perm_acc_reps_draw{subj,ana,step} = mtemp;
                clear mtemp;
                
                if ANALYSIS.plot_robust == 1 % If plotting trimmed mean for group-level stats
                    
                    trimmed_mtemp = trimmean(temp, ANALYSIS.plot_robust_trimming, 1);
                    ANALYSIS.RES.trimmean_all_subj_perm_acc_reps_draw{subj,ana,step} = trimmed_mtemp;  
                    clear trimmed_mtemp;
                    
                elseif ANALYSIS.plot_robust == 2 % If plotting median for group-level stats
                    
                    median_mtemp = median(temp, 1);
                    ANALYSIS.RES.median_all_subj_perm_acc_reps_draw{subj,ana,step} = median_mtemp;  
                    clear median_mtemp;
                    
                end % of if ANALYSIS.plot_robust
                clear temp; 
                
            end % step
        end % ana
    end % sbj

end % of if ANALYSIS.permstats == 2 statement

fprintf('All data from all subjects averaged.\n');

%% STATISTICAL TESTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%__________________________________________________________________________


if ANALYSIS.group_level_analysis == 1 % Group-level stats based on the minimum statistic
    
    [ANALYSIS] = min_statistic_classifier_accuracies(ANALYSIS);
    
elseif ANALYSIS.group_level_analysis == 2 % Group-level stats based on t tests
    
    [ANALYSIS] = t_tests_classifier_accuracies(ANALYSIS);

end % of if ANALYSIS.group_level_analysis


fprintf('All group statistics performed.\n');

%% FEATURE WEIGHT ANALYSIS
%__________________________________________________________________________

if ANALYSIS.fw.do == 1 % If chosen to analyse feature weights
    
    [FW_ANALYSIS] = analyse_feature_weights_erp(ANALYSIS);
    
else
    
    FW_ANALYSIS = [];
    
end


%% SAVE RESULTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%__________________________________________________________________________

if size(ANALYSIS.dcg_todo,2) == 1 % Standard decoding analyses

    savename = [(ANALYSIS.output_dir) ANALYSIS.study_name '_GROUPRES_NSBJ' num2str(ANALYSIS.nsbj) '_win'...
        num2str(ANALYSIS.window_width_ms) '_steps' num2str(ANALYSIS.step_width_ms)...
        '_av' num2str(ANALYSIS.avmode) '_st' num2str(ANALYSIS.stmode) '_' ANALYSIS.analysis_mode_label...
        '_DCG' ANALYSIS.dcg_labels{ANALYSIS.dcg_todo} '.mat'];
    
elseif size(ANALYSIS.dcg_todo,2) == 2 % Cross-condition decoding analyses
    
    savename = [(ANALYSIS.output_dir) ANALYSIS.study_name '_GROUPRES_NSBJ' num2str(ANALYSIS.nsbj) '_win'...
        num2str(ANALYSIS.window_width_ms) '_steps' num2str(ANALYSIS.step_width_ms)...
        '_av' num2str(ANALYSIS.avmode) '_st' num2str(ANALYSIS.stmode) '_' ANALYSIS.analysis_mode_label...
        '_DCG' ANALYSIS.dcg_labels{ANALYSIS.dcg_todo(1)}...
        'toDCG' ANALYSIS.dcg_labels{ANALYSIS.dcg_todo(2)} '.mat'];

end

save(savename,'ANALYSIS','FW_ANALYSIS','-v7.3');

fprintf('All results saved in %s. \n',savename);


%% PLOT DATA %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%__________________________________________________________________________

if ANALYSIS.disp.on == 1
    
    fprintf('Results will be plotted. \n');
    display_group_results_erp(ANALYSIS);
    
elseif ANALYSIS.disp.on ~= 1
    
    fprintf('No figures were produced for the results. \n');
    
end

%__________________________________________________________________________
