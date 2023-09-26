
classdef Label3DImage_viewsep < Label3D
    properties (Access = public)
        imageNames
        nview
    end
    
    methods
        function obj = Label3DImage_viewsep(varargin)
            
            % Check for loading from state
            assert(numel(varargin) == 3)
            params = varargin{1};
            images = varargin{2};
            if ~iscell(images)
                if isfolder(images)
                    folder = images;
                    files = cat(1, dir(fullfile(folder, '*view0*.jpg')), ...
                                dir(fullfile(folder, '*view0*.jpeg')), ...
                                dir(fullfile(folder, '*view0*.png')));
                    images = arrayfun(@(x)fullfile(x.folder, x.name), ...
                                files, 'uni', false);
                elseif isfile(images)
                    images = {images};
                else
                    error('No such format');
                end
            end
            obj.imageNames = images;
            skeleton = varargin{3};
            nview = length(params);
            obj.nview = nview;
            nfile = length(images);
            imgs = cell(nview, nfile);
            f = waitbar(0, 'Starting');
            for ifile = 1:nfile
                waitbar(ifile/nfile, f, sprintf('Progress: %d / %d', ifile, nfile));
                img0 = images{ifile};
                [folder, img0_nake, ext] = fileparts(img0);
                for iview = 1:nview
                    img_now_nake = replace(img0_nake, 'view0', ['view', int2str(iview-1)]);
                    img_now = fullfile(folder, [img_now_nake, ext]);
                    imgs{iview, ifile} = imread(img_now);
                end
            end
            close(f)
            videos = cell(nview, 1);
            for iview = 1:nview
                subimgs = imgs(iview,:)';
                videos{iview} = cat(4, subimgs{:});
            end
            % Ask for files to load, or load in multiple files.
            obj.buildFromScratch(params, videos, skeleton)
        end
        
        function saveState(obj)
            disp('saving')
            status = obj.status;
            skeleton = obj.skeleton;
            imageSize = obj.ImageSize;
            cameraPoses = obj.cameraPoses;
            imageNames = obj.imageNames;
            % Reshape to dannce specifications
            % Only take the labeled frames
            pts3D = obj.points3D;
            data_3D = permute(pts3D, [3 2 1]);
            data_3D = reshape(data_3D, size(data_3D, 1), []);
            %             data_3D(~any(~isnan(data_3D),2),:) = [];
            %             pts3D(any(~any(~isnan(pts3D),2),3),:,:) = [];
            
            camParams = obj.origCamParams;
            path = sprintf('%s.mat', obj.savePath);
            save(path, 'data_3D', 'status', 'imageNames', ...
                'skeleton', 'imageSize', 'cameraPoses','camParams')
            fprintf('保存共有 %d/%d 张标注图片\n', ...
                    sum(any(~isnan(data_3D), 2)), ...
                    size(data_3D,1))
        end
        
        function resetAspectRatio(obj)
            % aspect ratio of all images is set to 1:1
            for i = 1:obj.nCams
                thisAx = obj.h{i}.Axes;
                img = obj.h{i}.img.CData(:,:,1);
                x_rg = sum(img>2, 1)>5;
                x_bg = find(x_rg, 1, 'first');
                x_end = find(x_rg, 1, 'last');
                y_rg = sum(img>2, 2)>5;
                y_bg = find(y_rg, 1, 'first');
                y_end = find(y_rg, 1, 'last');

                if isempty(x_bg) || x_bg==x_end
                    thisAx.XLim=[0 50]; thisAx.YLim=[0 50];
                    continue;
                end
                x_center = mean([x_bg, x_end]);
                y_center = mean([y_bg, y_end]);
                max_rg = max(max(x_end-x_bg, y_end-y_bg), 50);
                newRange = max_rg /2 *[-1, 1] + [-20, 20];
                thisAx.XLim = x_center + newRange;
                thisAx.YLim = y_center + newRange;
                axis(thisAx, 'tight');
            end
        end
    end
end