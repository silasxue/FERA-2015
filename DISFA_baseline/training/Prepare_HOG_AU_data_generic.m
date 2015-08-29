function [data_train, labels_train, data_valid, labels_valid, raw_valid, PC, means_norm, stds_norm, vid_ids_valid] = ...
    Prepare_HOG_AU_data_generic(all_users, au_train, rest_aus, hog_data_dir, offset, prop)

%% This should be a separate function?

input_train_label_files = cell(numel(all_users),1);
    
if(exist('F:/datasets/DISFA/', 'file'))
    root = 'F:/datasets/DISFA/';
elseif(exist('D:/Databases/DISFA/', 'file'))        
    root = 'D:/Databases/DISFA/';
elseif(exist('D:/Datasets/DISFA/', 'file'))        
    root = 'D:/Datasets/DISFA/';    
elseif(exist('Z:/datasets/DISFA/', 'file'))        
    root = 'Z:/Databases/DISFA/';
elseif(exist('E:/datasets/DISFA/', 'file'))        
    root = 'E:/datasets/DISFA/';
elseif(exist('C:/tadas/DISFA/', 'file'))        
    root = 'C:/tadas/DISFA/';
elseif(exist('D:\datasets\face_datasets\DISFA/', 'file'))        
    root = 'D:\datasets\face_datasets\DISFA/';
else
    fprintf('DISFA location not found (or not defined)\n'); 
end
    
% This is for loading the labels
for i=1:numel(all_users)   
    input_train_label_files{i} = [root, '/ActionUnit_Labels/', all_users{i}, '/', all_users{i}];
end

% Extracting the labels
labels_train = extract_au_labels(input_train_label_files, au_train);
    
labels_other = zeros(size(labels_train,1), numel(rest_aus));

% This is used to pick up activity of other AUs for a more 'interesting'
% data split and not only neutral expressions for negative samples    
for i=1:numel(rest_aus)
    labels_other(:,i) = extract_au_labels(input_train_label_files, rest_aus(i));
end
    
% Reading in the HOG data
[train_geom_data] = Read_geom_files(all_users, hog_data_dir);

[train_appearance_data, tracked_inds_hog, vid_ids_train] = Read_HOG_files(all_users, hog_data_dir);

train_appearance_data = cat(2, train_appearance_data, train_geom_data);

if(nargin <= 4)
    offset = 1;
    prop = 1/4;
end

% Getting the indices describing the splits (full version)
[training_inds, valid_inds] = construct_indices(all_users, vid_ids_train, au_train, offset, prop);

% can now extract the needed training labels (do not rebalance validation
% data)
labels_valid = labels_train(valid_inds);
vid_ids_valid = vid_ids_train(valid_inds);

% make sure the same number of positive and negative samples is taken
reduced_inds = false(size(labels_train,1),1);
reduced_inds(labels_train > 0 & training_inds) = true;

% make sure the same number of positive and negative samples is taken
pos_count = sum(labels_train(training_inds) > 0);
neg_count = sum(labels_train(training_inds) == 0);

% pos_count = pos_count * 8;

num_other = floor(pos_count / (size(labels_other, 2)));

inds_all = 1:size(labels_train,1);

for i=1:size(labels_other, 2)+1
   
    if(i > size(labels_other, 2))
        % fill the rest with a proportion of neutral
        inds_other = inds_all(sum(labels_other,2)==0 & ~labels_train & training_inds);   
        num_other_i = min(numel(inds_other), pos_count - sum(labels_train(reduced_inds,:)==0));     
    else
        % take a proportion of each other AU
        inds_other = inds_all(labels_other(:, i) & ~labels_train & training_inds );      
        num_other_i = min(numel(inds_other), num_other);        
    end
    inds_other_to_keep = inds_other(round(linspace(1, numel(inds_other), num_other_i)));
    reduced_inds(inds_other_to_keep) = true;
    
end

% Remove invalid ids based on CLM failing or AU not being labelled
reduced_inds(~tracked_inds_hog) = false;

training_inds = reduced_inds;

labels_train = labels_train(training_inds);

% normalise the data
pca_file = '../../pca_generation/generic_face_rigid.mat';
load(pca_file);
     
PC_n = zeros(size(PC)+size(train_geom_data, 2));
PC_n(1:size(PC,1), 1:size(PC,2)) = PC;
PC_n(size(PC,1)+1:end, size(PC,2)+1:end) = eye(size(train_geom_data, 2));
PC = PC_n;

means_norm = cat(2, means_norm, zeros(1, size(train_geom_data,2)));
stds_norm = cat(2, stds_norm, ones(1, size(train_geom_data,2)));

% Grab all data for validation as want good params for all the data
raw_valid = train_appearance_data(valid_inds,:);

valid_appearance_data = bsxfun(@times, bsxfun(@plus, train_appearance_data(valid_inds,:), -means_norm), 1./stds_norm);
train_appearance_data = bsxfun(@times, bsxfun(@plus, train_appearance_data(training_inds,:), -means_norm), 1./stds_norm);

data_train = train_appearance_data * PC;
data_valid = valid_appearance_data * PC;

end

function [training_inds, valid_inds] = construct_indices(all_users, video_inds, au, offset, prop)

    % extract these separately so as to guarantee person independent splits for
    % validation

    [users_train, users_valid] = get_balanced_fold(all_users, au, prop, offset);
    
%     users_train = train_users(1:split);

    training_inds = false(size(video_inds));
    for i=1:numel(users_train)
        user_ind = strcmp(video_inds,  users_train(i));
        training_inds = training_inds | user_ind;
    end
    
%     users_valid = train_users(split+1:end);
    valid_inds = false(size(video_inds));
    for i=1:numel(users_valid)
        user_ind = strcmp(video_inds,  users_valid(i));
        valid_inds = valid_inds | user_ind;
    end        
end