function cpmri(info, opt, subj)
%CPMRI copy MRI images into subject-folder and normalize them
%
% CFG
%  .rec: name of the recordings (part of the structrual filename)

% INFO
%  .data: path of /data1/projects/PROJ/subjects/
%  .rec: REC in /data1/projects/PROJ/recordings/REC/
%  .vol.mod: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/
%  .vol.cond: name to be used in projects/PROJNAME/subjects/0001/VOLMOD/VOLCONDNAME/
%  .smri: folder containing all the MRI images
%  .log: name of the file and directory to save log
%
% CFG.OPT
%  .normalize: normalization ('none' 'spm8' 'flirt')
%  .smri: directory to copy all the structrual data to (can be empty)
%
% * indicates obligatory parameter
%
% Part of MRI2LEAD
% see also CPMRI, MRI2BND, FREESURFER2BND, BND2LEAD, USETEMPLATE

%---------------------------%
%-start log
output = sprintf('%s (%04d) began at %s on %s\n', ...
  mfilename, subj, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'));
tic_t = tic;
%---------------------------%

%---------------------------%
%-dir and files
ft_hastoolbox('spm8', 2);

rdir = sprintf('%s%04.f/%s/%s/', info.recs, subj, info.vol.mod, 'raw'); % recording
mdir = sprintf('%s%04.f/%s/%s/', info.data, subj, info.vol.mod, info.vol.cond); % mridata dir
if ~isdir(mdir); mkdir(mdir); end

rfile = sprintf('%s_%04.f_%s_%s', info.rec, subj, info.vol.mod, info.vol.cond); % recording
mfile = sprintf('%s_%04.f_%s_%s', info.rec, subj, info.vol.mod, info.vol.cond); % mridata

ext = '.nii.gz';
%---------------------------%

if exist([rdir rfile ext], 'file')
  
  %---------------------------%
  %-get data
  if ~exist([mdir mfile ext], 'file')
    bash(['ln ' rdir rfile ext ' ' mdir mfile ext]);
  end
  %---------------------------%
  
  if strcmp(opt.normalize, 'flirt')
    %-----------------------------------------------%
    %-USE FLIRT
    
    %---------------------------%
    %-realign
    %-------%
    %-bet
    bash(['bet ' mdir mfile ' ' mdir mfile '_brain -f 0.5 -g 0']);
    %-------%
    
    %-------%
    %-flirt
    bash(['flirt -in ' mdir mfile '_brain -ref /usr/share/data/fsl-mni152-templates/MNI152_T1_1mm_brain.nii.gz ' ...
      '-out ' mdir mfile '_brain_flirt -omat ' mdir mfile '_brain_flirt.mat ' ...
      '-bins 256 -cost corratio -searchrx -90 90 -searchry -90 90 -searchrz -90 90 -dof 12  -interp trilinear']);
    %-------%
    
    %-------%
    %-fnirt
    %-------%
    
    %-------%
    %-apply flirt
    bash(['flirt -in ' mdir mfile ' -ref /usr/share/data/fsl-mni152-templates/MNI152_T1_1mm_brain.nii.gz ' ...
      '-out ' mdir mfile '_' opt.normalize ' -applyxfm -init ' mdir mfile '_brain_flirt.mat']);
    %-------%
    
    %-------%
    %-feedback
    aff = dlmread([mdir mfile '_brain_flirt.mat']);
    
    outtmp = sprintf('flirt affine matrix:\n');
    for i = 1: (size(aff,1)-1)
      outtmp = sprintf('%s%s\n', outtmp, sprintf('% 9.3f', aff(i,:)));
    end
    output = [output outtmp];
    %-------%
    
    %-------%
    %-delete
    % delete([mdir '*_brain*'])
    %-------%
    %---------------------------%
    appendname = ['_' opt.normalize];
    %-----------------------------------------------%
    
  elseif strcmp(opt.normalize, 'spm8')
    
    %-----------------------------------------------%
    %-spm
    %---------------------------%
    %-defaults for SPM
    refimg = [fullfile(fileparts(which('spm')), 'templates/T1.nii') ',1'];
    outsn = [mdir mfile '_sn.mat'];
    %-----------------%
    %-unzip
    gunzip([mdir mfile ext]);
    %-----------------%
    %---------------------------%
    
    %---------------------------%
    %-normalize
    eflags = [];
    eflags.smosrc = 8;
    eflags.smoref = 0;
    eflags.regtype = 'mni';
    eflags.cutoff = 25;
    eflags.nits = 16;
    eflags.reg = 1;
    
    spm_normalise(refimg, [mdir mfile ext(1:4)], outsn, '', '', eflags);
    %---------------------------%
    
    %---------------------------%
    %-write
    rflags = [];
    rflags.preserve = 0;
    rflags.bb = [-100  -120 -100; 100 100 110];
    rflags.vox = [1 1 1];
    rflags.interp = 1;
    rflags.wrap = [0 0 0];
    rflags.prefix = 'w';
    spm_write_sn([mdir mfile ext(1:4)], outsn, rflags);
    %---------------------------%
    
    %---------------------------%
    %-clean up
    uncomp = [mdir mfile '_' opt.normalize ext(1:4)];
    bash(['mv ' mdir rflags.prefix mfile ext(1:4) ' ' uncomp]);
    gzip(uncomp);
    
    delete([mdir mfile ext(1:4)])
    delete(uncomp);
    %---------------------------%
    appendname = ['_' opt.normalize];
    %-----------------------------------------------%
    
  else
    appendname = '';
  end
  
  %---------------------------%
  %-copy data to main directory
  if ~isempty(info.smri)
    bash(['ln ' mdir mfile appendname '.nii.gz ' info.smri mfile appendname ext]);
  end
  %---------------------------%
  
  
else
  
  outtmp = sprintf('%s for subject % 2.f does not exist\n', [rdir rfile ext], subj);
  output = [output outtmp];
  
end

%---------------------------%
%-end log
toc_t = toc(tic_t);
outtmp = sprintf('%s (%04d) ended at %s on %s after %s\n\n', ...
  mfilename, subj, datestr(now, 'HH:MM:SS'), datestr(now, 'dd-mmm-yy'), ...
  datestr( datenum(0, 0, 0, 0, 0, toc_t), 'HH:MM:SS'));
output = [output outtmp];

%-----------------%
fprintf(output)
fid = fopen([info.log '.txt'], 'a');
fwrite(fid, output);
fclose(fid);
%-----------------%
%---------------------------%