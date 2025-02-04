
classdef Label3DImageManager_marmoset < handle
    properties (Access = public)
        Parent
        labelGui
        imagefolder = './'
    end
    methods
        function obj = Label3DImageManager_marmoset()
            obj.Parent = figure('toolbar', 'figure', 'menubar', 'none');
            a = uimenu(obj.Parent, 'Text', '文件');
            uimenu(a, 'Text', '1. 打开文件夹', 'callback', @(src, evt)obj.load_folder(src, evt));
            uimenu(a, 'Text', '2. 载入标注文件', 'callback', @(src, evt)obj.load_anno(src, evt));
            uimenu(a, 'Text', '3. 保存标注文件', 'callback', @(src, evt)obj.save_anno(src, evt));
            tags = {'Standard.OpenInspector', 'Standard.EditPlot', ...
                    'Annotation.InsertLegend', 'Annotation.InsertColorbar',...
                    'DataManager.Linking', 'Standard.PrintFigure',...
                    'Standard.SaveFigure', 'Standard.FileOpen',...
                    'Standard.NewFigure'};
            for i = 1:length(tags)
                tag = tags{i};
                set(findall(obj.Parent, 'tag', tag), 'visible', 'off');
            end
        end
        
        function load_folder(obj, ~, ~)
            obj.imagefolder = uigetdir();
            if isequal(obj.imagefolder, 0); return; end
            skeleton = get_skeleton();
            params = get_params(obj.imagefolder);
            delete(findobj(obj.Parent, 'type', 'axes'));
            set(obj.Parent,  'WindowKeyPressFcn', '');
            disp('正在载入图片，需要半分钟');
            obj.labelGui = Label3DImage(params, obj.imagefolder, skeleton);
            if ~obj.labelGui.isKP3Dplotted; obj.labelGui.add3dPlot(); end
            set(get(obj.labelGui.statusAnimator.Axes, 'Parent'), 'visible', 'off');
            fprintf('载入 %d 张图片。 接下来可以“载入标注文件”\n', ...
                    size(obj.labelGui.points3D, 3));
            obj.labelGui.resetAspectRatio();
        end 
        
        function load_anno(obj, ~, ~)
            [file, path] = uigetfile('*.mat');
            if isequal(file, 0); return; end
            annofile = fullfile(path,file);
            mat = load(annofile, '-mat');
            if ~isfield(mat, 'data_3D') || ~isfield(mat, 'imageNames')
                warning('Not valid anno file');
                return;
            end
            mat_data3D = mat.data_3D;
            ind_labeled = any(~isnan(mat_data3D), 2);
            if sum(ind_labeled)==0
                warning('文件中标注为空')
                return;
            elseif sum(ind_labeled)==length(ind_labeled)
                disp('文件所有图片均被标注')
            else
                fprintf('文件有 %d/%d 张图片被标注\n', sum(ind_labeled),length(ind_labeled))
            end
            mat_data3D = mat_data3D(ind_labeled,:);
            mat.imageNames = reshape(mat.imageNames, [], 1);
            mat_imageNames = get_nake_filename(mat.imageNames);
            mat_imageNames = mat_imageNames(ind_labeled, :);
            gui_imageNames = get_nake_filename(obj.labelGui.imageNames);
            [C, ia, ib] = intersect(gui_imageNames, mat_imageNames, 'stable');
            assert(~isempty(C))
            data_3D = permute(obj.labelGui.points3D, [3,2,1]);
            data_3D = reshape(data_3D, size(data_3D, 1), []);
            data_3D_tmp = data_3D(ia,:);
            outer_3D_tmp = mat_data3D(ib,:);
            data_3D_tmp(~isnan(outer_3D_tmp)) = outer_3D_tmp(~isnan(outer_3D_tmp));
            data_3D(ia,:) = data_3D_tmp;
            fprintf('载入 %d 张标注\n', length(C));   
            obj.labelGui.loadFrom3D(data_3D)
        end
        
        function save_anno(obj, ~, ~)
            pre = obj.labelGui.savePath;
            obj.labelGui.savePath = fullfile(obj.imagefolder, 'anno');
            obj.labelGui.saveState()
            obj.labelGui.savePath = pre;
        end
    end
end

function skeleton = get_skeleton()
    skeleton.joints_idx = [1,2;1,3;2,4;3,4;4,5;4,7;4,10;10,11;11,12;
        7,8;8,9;5,6;6,13;6,15;15,16;13,14;];
%     skeleton.joint_names = {'Nose','EarL','EarR','Neck','Back', ...
%         'Tail','ForeShoulderL','ForePowL','ForeShoulderR', ...
%         'ForePowR','BackShoulderL','BackPowL', ...
%         'BackShoulderR','BackPowR'};
    skeleton.joint_names = {'鼻','左<耳>','右<耳>','脖','背', ...
        '尾','左前<肩>','左前<肘>','左前<掌>','右前<肩>','右前<肘>', ...
        '右前<掌>','左后<肘>','左后<掌>', ...
        '右后<肘>','右后<掌>'};
    skeleton.color = [1,0.98,0.69;
        0.97,0.43,0.37;
        0.45,0.85,1;
        0.45,0.85,1;
        1,0.49,0.0;
        0.30,0.71,1;
        1,0.98,0.69;
        1,0.98,0.69;
        0.41,0.23,0.60;
        1,0.49,0.0;
        0.30,0.71,1;
        0.30,0.71,1;
        0.89,0.23,0.24;
        0.89,0.23,0.24;
        1.00,1.00,0.60;
        0.15,0.30,1];
end

function params = get_params(imagefolder)
%     assert(exist(imagefolder, 'dir'), '文件夹不存在');
    files = dir(fullfile(imagefolder, '*.calibpkl.mat'));
    nfile = length(files);
    if nfile>1; error('多个 calibpkl.mat 文件在里面'); end
    if nfile==0; error('没有 calibpkl.mat 文件在里面'); end
    calib_mat = fullfile(imagefolder, files(1).name);
    MAT = load(calib_mat, 'ba_poses');
    ba_poses = MAT.ba_poses;
    params = cell(numel(ba_poses), 1);
    for i = 1:numel(ba_poses)
        param = struct();
        pose = ba_poses{i};
        K    = pose.K;
        dist = pose.dist(1:5);
        R    = pose.R;
        t    = pose.t;
        param.K = K' + [0, 0, 0;0, 0, 0; 1, 1, 0];
        param.RDistort = [dist(1:2), dist(5:end)];
        param.TDistort = dist(3:4);
        param.t = t;
        param.r = R';
        params{i} = param;
    end
end

function out = get_nake_filename(imageNames)
    out = cell(size(imageNames));
    for i=1:length(imageNames)
        imageName = imageNames{i};
        [~,name,ext] = fileparts(imageName);
        out{i} = [name, ext];
    end
end