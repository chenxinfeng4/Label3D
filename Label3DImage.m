classdef Label3DImage < Label3D
    %Label3D - Label3D is a GUI for manual labeling of 3D keypoints in multiple cameras.
    %
    %Input format 1: Build from scratch
    %   camParams: Cell array of structures denoting camera
    %              parameters for each camera.
    %           Structure has five fields:
    %               K - Intrinsic Matrix
    %               RDistort - Radial distortion
    %               TDistort - Tangential distortion
    %               r - Rotation matrix
    %               t - Translation vector
    %   videos: Cell array of h x w x c x nFrames videos.
    %   skeleton: Structure with three fields:
    %       skeleton.color: nSegments x 3 matrix of RGB values
    %       skeleton.joints_idx: nSegments x 2 matrix of integers
    %           denoting directed edges between markers.
    %       skeleton.joint_names: cell array of names of each joint
    %   Syntax: Label3D(camParams, videos, skeleton, varargin);
    %
    %Input format 2: Load from state
    %   file: Path to saved Label3D state file (with or without
    %   video)
    %   videos: Cell array of h x w x c x nFrames videos.
    %   Syntax: Label3D(file, videos, varargin);
    %
    %Input format 3: Load from file
    %   file: Path to saved Label3D state file (with video)
    %   Syntax: Label3D(file, varargin);
    %
    %Input format 4: Load and merge multiple files
    %   file: cell array of paths to saved Label3D state files (with video)
    %   Syntax: Label3D(file, varargin);
    %
    %Input format 5: Load GUI file selection
    %   Syntax: Label3D(varargin);
    %
    % Instructions:
    % right: move forward one frameRate
    % left: move backward one frameRate
    % up: increase the frameRate
    % down: decrease the frameRate
    % t: triangulate points in current frame that have been labeled in at least two images and reproject into each image
    % r: reset gui to the first frame and remove Animator restrictions
    % u: reset the current frame to the initial marker positions
    % z: Toggle zoom state
    % p: Show 3d animation plot of the triangulated points.
    % backspace: reset currently held node (first click and hold, then
    %            backspace to delete)
    % pageup: Set the selectedNode to the first node
    % tab: shift the selected node by 1
    % shift+tab: shift the selected node by -1
    % h: print help messages for all Animators
    % shift+s: Save the data to a .mat file
    %
    %   Label3D Properties:
    %   cameraParams - Camera Parameters for all cameras
    %   cameraPoses - Camera poses for all cameras
    %   orientations - Orientations of all cameras
    %   locations - Locations of all cameras
    %   camPoints - Positions of all points in camera coordinates
    %   points3D - Positions of all points in world XYZ coordinates
    %   status - Logical matrix denoting whether a node has been modified
    %   selectedNode - Currently selected node for click updating
    %   skeleton - Struct denoting directed graph
    %   ImageSize - Size of the images
    %   nMarkers - Number of markers
    %   nCams - Number of Cameras
    %   jointsPanel - Handle to keypoint panel
    %   jointsControl - Handle to keypoint controller
    %   savePath - Path in which to save data.
    %   h - Cell array of Animator handles.
    %   frameInds - Indices of current subset of frames
    %   frame - Current frame number within subset
    %   frameRate - current frame rate
    %   undistortedImages - If true, treat input images as undistorted
    %                       (Default false)
    %   savePath - Path in which to save output. The output files are of
    %              the form
    %              path = sprintf('%s%sCamera_%d.mat', obj.savePath,...
    %                       datestr(now,'yyyy_mm_dd_HH_MM_SS'), nCam);
    %   verbose - Print saving messages
    %
    %   Label3D Methods:
    %   Label3D - constructor
    %   loadcamParams - Load in camera parameters
    %   getCameraPoses - Return table of camera poses
    %   zoomOut - Zoom all images out to full size
    %   getLabeledJoints - Return the indices of labeled joints and
    %       corresponding cameras in a frame.
    %   triangulateLabeledPoints - Return xyz positions of labeled joints.
    %   reprojectPoints - reproject points from world coordinates to the
    %       camera reference frames
    %   resetFrame - reset all labels to the initial positions within a
    %       frame.
    %   clickImage - Assign the position of the selected node with the
    %       position of a mouse click.
    %   getPointTrack - Helper function to return pointTrack object for
    %       current frame.
    %   plotCameras - Plot the positions and orientations of all cameras in
    %       world coordinates.
    %   checkStatus - Check whether points have been moved and update
    %       accordingly
    %   keyPressCallback - handle UI
    %   saveState - save the current labeled data to a mat file.
    %   selectNode - Modify the current selected node.
    %
    %   Written by Diego Aldarondo (2019)
    %   Some code adapted from https://github.com/talmo/leap

    properties (Constant)
        views_1280x800x10 = {[1280*0, 800*0, 1280, 800];
                 [1280*1, 800*0, 1280, 800];
                 [1280*2, 800*0, 1280, 800];
                 [1280*0, 800*1, 1280, 800];
                 [1280*1, 800*1, 1280, 800];
                 [1280*2, 800*1, 1280, 800];
                 [1280*0, 800*2, 1280, 800];
                 [1280*1, 800*2, 1280, 800];
                 [1280*2, 800*2, 1280, 800];
                 [1280*0, 800*3, 1280, 800]}
         views_1280x800x9 = {[1280*0, 800*0, 1280, 800];
                 [1280*1, 800*0, 1280, 800];
                 [1280*2, 800*0, 1280, 800];
                 [1280*0, 800*1, 1280, 800];
                 [1280*1, 800*1, 1280, 800];
                 [1280*2, 800*1, 1280, 800];
                 [1280*0, 800*2, 1280, 800];
                 [1280*1, 800*2, 1280, 800];
                 [1280*2, 800*2, 1280, 800]}
         views_1280x800x4 = {[1280*0, 800*0, 1280, 800];
                 [1280*1, 800*0, 1280, 800];
                 [1280*0, 800*1, 1280, 800];
                 [1280*1, 800*1, 1280, 800]}
         views_800x600x6 = {[800*0, 600*0, 800, 600];
                 [800*1, 600*0, 800, 600];
                 [800*2, 600*0, 800, 600];
                 [800*0, 600*1, 800, 600];
                 [800*1, 600*1, 800, 600];
                 [800*2, 600*1, 800, 600]}
          views_2048x2448x6 = {[2448*0, 2048*0, 2448, 2048];
                 [2448*1, 2048*0, 2448, 2048];
                 [2448*2, 2048*0, 2448, 2048];
                 [2448*0, 2048*1, 2448, 2048];
                 [2448*1, 2048*1, 2448, 2048];
                 [2448*2, 2048*1, 2448, 2048]}
          views_640x480x6 = {[640*0, 480*0, 640, 480];
                 [640*1, 480*0, 640, 480];
                 [640*2, 480*0, 640, 480];
                 [640*0, 480*1, 640, 480];
                 [640*1, 480*1, 640, 480];
                 [640*2, 480*1, 640, 480]
              }
          views_2560x1440x5 = {[2560*0, 1440*0, 2560, 1440];
                 [2560*1, 1440*0, 2560, 1440];
                 [2560*2, 1440*0, 2560, 1440];
                 [2560*0, 1440*1, 2560, 1440];
                 [2560*1, 1440*1, 2560, 1440]
              }
    end
    properties (Access = public)
        imageNames
        views
    end
    
    methods
        function obj = Label3DImage(varargin)
            
            % Check for loading from state
            assert(numel(varargin) == 3)
            params = varargin{1};
            images = varargin{2};
            if ~iscell(images)
                if isfolder(images)
                    folder = images;
                    files = cat(1, dir(fullfile(folder, '*.jpg')), ...
                                dir(fullfile(folder, '*.jpeg')), ...
                                dir(fullfile(folder, '*.png')));
                    images = arrayfun(@(x)fullfile(x.folder, x.name), ...
                                files, 'uni', false);
                elseif isfile(images)
                    images = {images};
                else
                    error('No such format');
                end
            end
            obj.imageNames = images;
            img = imread(images{1});
            if isequal(size(img), [1440, 2560, 3])
                obj.views = obj.views_800x600x6;
            elseif isequal(size(img), [600*2, 800*3, 3])
                obj.views = obj.views_800x600x6;
            elseif isequal(size(img), [800*4, 1280*3, 3])
                obj.views = obj.views_1280x800x10;
            elseif isequal(size(img), [800*3, 1280*3, 3])
                obj.views = obj.views_1280x800x9;
            elseif isequal(size(img), [800*2, 1280*2, 3])
                obj.views = obj.views_1280x800x4;
%             elseif isequal(size(img), [1440*5, 2560*1, 3])
%                 obj.views = obj.views_2560x1440x5;
            elseif isequal(size(img), [2048*2, 2448*3, 3])
                obj.views = obj.views_2048x2448x6;
            elseif isequal(size(img), [480*2, 640*3, 3])
                obj.views = obj.views_640x480x6;
            elseif isequal(size(img), [1440*2, 2560*3, 3])
                obj.views = obj.views_2560x1440x5;
            else
                error('No such picture arange.')
            end
            skeleton = varargin{3};
            nview = length(obj.views);
            nfile = length(images);
            imgs = cell(nview, nfile);
            f = waitbar(0, 'Starting');
            for ifile = 1:nfile
                waitbar(ifile/nfile, f, sprintf('Progress: %d / %d', ifile, nfile));
                img = imread(images{ifile});
                for iview = 1:nview
                    crop_xywh = obj.views{iview};
                    x=crop_xywh(1); y=crop_xywh(2); w=crop_xywh(3); h=crop_xywh(4);
                    img_crop = img(y+(1:h), x+(1:w), :);
                    imgs{iview, ifile} = img_crop;
                end
                clear img
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
            end
        end
    end
end