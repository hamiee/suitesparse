function spqr_make (opt1)
%SPQR_MAKE compiles the SuiteSparseQR mexFunctions
%
% Example:
%   spqr_make
%
% SuiteSparseQR relies on CHOLMOD, AMD, and COLAMD, and optionally CCOLAMD,
% CAMD, and METIS.  All but METIS are distributed with CHOLMOD.  To compile
% SuiteSparseQR to use METIS you must first place a copy of the metis-4.0
% directory (METIS version 4.0.1) in same directory that contains the AMD,
% COLAMD, CCOLAMD, CHOLMOD, and SuiteSparseQR directories.  Next, type
%
%   spqr_make
%
% in the MATLAB command window.  If METIS is not present in ../../metis-4.0,
% then it is not used.  See http://www-users.cs.umn.edu/~karypis/metis for a
% copy of METIS 4.0.1.
%
% To compile using Intel's Threading Building Blocks (TBB) use:
%
%   spqr_make ('tbb')
%
% TBB parallelism is not the default, since it conflicts with the multithreaded
% BLAS (the Intel MKL are OpenMP based, for example).  This may change in
% future versions.
%
% You must type the spqr_make command while in the SuiteSparseQR/MATLAB
% directory.
%
% See also spqr, spqr_solve, spqr_qmult, qr, mldivide

% Copyright 2008, Timothy A. Davis, http://www.suitesparse.com

details = 0 ;       % 1 if details of each command are to be printed, 0 if not

v = version ;
try
    % ispc does not appear in MATLAB 5.3
    pc = ispc ;
    mac = ismac ;
catch                                                                       %#ok
    % if ispc fails, assume we are on a Windows PC if it's not unix
    pc = ~isunix ;
    mac = 0 ;
end

flags = '' ;
is64 = (~isempty (strfind (computer, '64'))) ;
if (is64)
    % 64-bit MATLAB
    flags = '-largeArrayDims' ;
end

include = '-DNMATRIXOPS -DNMODIFY -I. -I../../AMD/Include -I../../COLAMD/Include -I../../CHOLMOD/Include -I../Include -I../../SuiteSparse_config' ;

% Determine if METIS is available
metis_path = '../../metis-4.0' ;
have_metis = exist ([metis_path '/Lib'], 'dir') ;

% Determine if TBB is to be used
if (nargin < 1)
    tbb = 0 ;
elseif (nargin < 2)
    tbb = strcmp (opt1, 'tbb') ;
end

% fix the METIS 4.0.1 rename.h file
if (have_metis)
    fprintf ('Compiling SuiteSparseQR with METIS for MATLAB Version %s\n', v) ;
    f = fopen ('rename.h', 'w') ;
    if (f == -1)
        error ('unable to create rename.h in current directory') ;
    end
    fprintf (f, '/* do not edit this file; generated by spqr_make */\n') ;
    fprintf (f, '#undef log2\n') ;
    fprintf (f, '#include "%s/Lib/rename.h"\n', metis_path) ;
    fprintf (f, '#undef log2\n') ;
    fprintf (f, '#define log2 METIS__log2\n') ;
    fprintf (f, '#include "mex.h"\n') ;
    fprintf (f, '#define malloc mxMalloc\n') ;
    fprintf (f, '#define free mxFree\n') ;
    fprintf (f, '#define calloc mxCalloc\n') ;
    fprintf (f, '#define realloc mxRealloc\n') ;
    fclose (f) ;
    include = [include ' -I' metis_path '/Lib'] ;
    include = [include ' -I../../CCOLAMD/Include -I../../CAMD/Include' ] ;
else
    fprintf ('Compiling SuiteSparseQR without METIS on MATLAB Version %s\n', v);
    include = ['-DNPARTITION ' include ] ;
end

%-------------------------------------------------------------------------------
% BLAS option
%-------------------------------------------------------------------------------

% This is exceedingly ugly.  The MATLAB mex command needs to be told where to
% find the LAPACK and BLAS libraries, which is a real portability nightmare.
% The correct option is highly variable and depends on the MATLAB version.

if (pc)
    if (verLessThan ('matlab', '6.5'))
        % MATLAB 6.1 and earlier: use the version supplied in CHOLMOD
        lib = '../../CHOLMOD/MATLAB/lcc_lib/libmwlapack.lib' ;
    elseif (verLessThan ('matlab', '7.5'))
        % use the built-in LAPACK lib (which includes the BLAS)
        lib = 'libmwlapack.lib' ;
    else
        % need to also use the built-in BLAS lib 
        lib = 'libmwlapack.lib libmwblas.lib' ;
    end
else
    if (verLessThan ('matlab', '7.5'))
        % MATLAB 7.5 and earlier, use the LAPACK lib (including the BLAS)
        lib = '-lmwlapack' ;
    else
        % MATLAB 7.6 requires the -lmwblas option; earlier versions do not
        lib = '-lmwlapack -lmwblas' ;
    end
end

if (is64 && ~verLessThan ('matlab', '7.8'))
    % versions 7.8 and later on 64-bit platforms use a 64-bit BLAS
    fprintf ('with 64-bit BLAS\n') ;
    flags = [flags ' -DBLAS64'] ;
end

%-------------------------------------------------------------------------------
% TBB option
%-------------------------------------------------------------------------------

% You should install TBB properly so that mex can find the library files and
% include files, but you can also modify the tbb_lib_path and tbb_include_path
% strings below to if you need to specify the path to your own installation of
% TBB.

% vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
% >>>>>>>>>>>>>>>>>>>>> EDIT THE tbb_path BELOW AS NEEDED <<<<<<<<<<<<<<<<<<<<<<
if (pc)
    % For Windows, with TBB installed in C:\TBB.  Edit this line as needed:
    tbb_path = 'C:\TBB\tbb21_009oss' ;
else
    % For Linux, edit this line as needed (not needed if already in /usr/lib):
    tbb_path = '/cise/homes/davis/Install/tbb21_009oss' ;
end
% ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

% You should not have to edit the lines below.
if (pc)
    if (is64)
        tbb_lib_path = [tbb_path '\ia32\vc9\lib\'] ;
    else
        tbb_lib_path = [tbb_path '\em64t\vc9\lib\'] ;
    end
    tbb_include_path = [tbb_path '\include\'] ;
else
    % For Linux, with TBB might be already installed in /usr/lib
    if (exist ('/usr/lib/libtbb.so', 'file'))
        % do not edit these lines
        tbb_path = '' ;
        tbb_lib_path = '' ;
        tbb_include_path = '' ;
    else
        if (is64)
            tbb_lib_path = '/em64t/cc4.1.0_libc2.4_kernel2.6.16.21/lib' ;
        else
            tbb_lib_path = '/ia32/cc4.1.0_libc2.4_kernel2.6.16.21/lib' ;
        end
        tbb_lib_path = [tbb_path tbb_lib_path] ;
        tbb_include_path = [tbb_path '/include/'] ;
    end
end

if (tbb)
    fprintf ('Compiling with Intel TBB parallelism\n') ;
    lib = [lib ' -L' tbb_lib_path ' -ltbb'] ;
    include = [include ' -I' tbb_include_path ' -DHAVE_TBB' ] ;
end

if (~(pc || mac))
    % for POSIX timing routine
    lib = [lib ' -lrt'] ;
end

%-------------------------------------------------------------------------------
% ready to compile ...
%-------------------------------------------------------------------------------

config_src = { '../../SuiteSparse_config/SuiteSparse_config' } ;

amd_c_src = { ...
    '../../AMD/Source/amd_1', ...
    '../../AMD/Source/amd_2', ...
    '../../AMD/Source/amd_aat', ...
    '../../AMD/Source/amd_control', ...
    '../../AMD/Source/amd_defaults', ...
    '../../AMD/Source/amd_dump', ...
    '../../AMD/Source/amd_global', ...
    '../../AMD/Source/amd_info', ...
    '../../AMD/Source/amd_order', ...
    '../../AMD/Source/amd_postorder', ...
    '../../AMD/Source/amd_post_tree', ...
    '../../AMD/Source/amd_preprocess', ...
    '../../AMD/Source/amd_valid' } ;

colamd_c_src = {
    '../../COLAMD/Source/colamd', ...
    '../../COLAMD/Source/colamd_global' } ;

% CAMD and CCOLAMD are not needed if we don't have METIS
camd_c_src = { ...
    '../../CAMD/Source/camd_1', ...
    '../../CAMD/Source/camd_2', ...
    '../../CAMD/Source/camd_aat', ...
    '../../CAMD/Source/camd_control', ...
    '../../CAMD/Source/camd_defaults', ...
    '../../CAMD/Source/camd_dump', ...
    '../../CAMD/Source/camd_global', ...
    '../../CAMD/Source/camd_info', ...
    '../../CAMD/Source/camd_order', ...
    '../../CAMD/Source/camd_postorder', ...
    '../../CAMD/Source/camd_preprocess', ...
    '../../CAMD/Source/camd_valid' } ;

ccolamd_c_src = {
    '../../CCOLAMD/Source/ccolamd', ...
    '../../CCOLAMD/Source/ccolamd_global' } ;

if (have_metis)

    metis_c_src = {
        'Lib/balance', ...
        'Lib/bucketsort', ...
        'Lib/ccgraph', ...
        'Lib/coarsen', ...
        'Lib/compress', ...
        'Lib/debug', ...
        'Lib/estmem', ...
        'Lib/fm', ...
        'Lib/fortran', ...
        'Lib/frename', ...
        'Lib/graph', ...
        'Lib/initpart', ...
        'Lib/kmetis', ...
        'Lib/kvmetis', ...
        'Lib/kwayfm', ...
        'Lib/kwayrefine', ...
        'Lib/kwayvolfm', ...
        'Lib/kwayvolrefine', ...
        'Lib/match', ...
        'Lib/mbalance2', ...
        'Lib/mbalance', ...
        'Lib/mcoarsen', ...
        'Lib/memory', ...
        'Lib/mesh', ...
        'Lib/meshpart', ...
        'Lib/mfm2', ...
        'Lib/mfm', ...
        'Lib/mincover', ...
        'Lib/minitpart2', ...
        'Lib/minitpart', ...
        'Lib/mkmetis', ...
        'Lib/mkwayfmh', ...
        'Lib/mkwayrefine', ...
        'Lib/mmatch', ...
        'Lib/mmd', ...
        'Lib/mpmetis', ...
        'Lib/mrefine2', ...
        'Lib/mrefine', ...
        'Lib/mutil', ...
        'Lib/myqsort', ...
        'Lib/ometis', ...
        'Lib/parmetis', ...
        'Lib/pmetis', ...
        'Lib/pqueue', ...
        'Lib/refine', ...
        'Lib/separator', ...
        'Lib/sfm', ...
        'Lib/srefine', ...
        'Lib/stat', ...
        'Lib/subdomains', ...
        'Lib/timing', ...
        'Lib/util' } ;

    for i = 1:length (metis_c_src)
        metis_c_src {i} = [metis_path '/' metis_c_src{i}] ;
    end
end

cholmod_c_src = {
    '../../CHOLMOD/Core/cholmod_aat', ...
    '../../CHOLMOD/Core/cholmod_add', ...
    '../../CHOLMOD/Core/cholmod_band', ...
    '../../CHOLMOD/Core/cholmod_change_factor', ...
    '../../CHOLMOD/Core/cholmod_common', ...
    '../../CHOLMOD/Core/cholmod_complex', ...
    '../../CHOLMOD/Core/cholmod_copy', ...
    '../../CHOLMOD/Core/cholmod_dense', ...
    '../../CHOLMOD/Core/cholmod_error', ...
    '../../CHOLMOD/Core/cholmod_factor', ...
    '../../CHOLMOD/Core/cholmod_memory', ...
    '../../CHOLMOD/Core/cholmod_sparse', ...
    '../../CHOLMOD/Core/cholmod_transpose', ...
    '../../CHOLMOD/Core/cholmod_triplet', ...
    '../../CHOLMOD/Check/cholmod_check', ...
    '../../CHOLMOD/Check/cholmod_read', ...
    '../../CHOLMOD/Check/cholmod_write', ...
    '../../CHOLMOD/Cholesky/cholmod_amd', ...
    '../../CHOLMOD/Cholesky/cholmod_analyze', ...
    '../../CHOLMOD/Cholesky/cholmod_colamd', ...
    '../../CHOLMOD/Cholesky/cholmod_etree', ...
    '../../CHOLMOD/Cholesky/cholmod_factorize', ...
    '../../CHOLMOD/Cholesky/cholmod_postorder', ...
    '../../CHOLMOD/Cholesky/cholmod_rcond', ...
    '../../CHOLMOD/Cholesky/cholmod_resymbol', ...
    '../../CHOLMOD/Cholesky/cholmod_rowcolcounts', ...
    '../../CHOLMOD/Cholesky/cholmod_rowfac', ...
    '../../CHOLMOD/Cholesky/cholmod_solve', ...
    '../../CHOLMOD/Cholesky/cholmod_spsolve', ...
    '../../CHOLMOD/Supernodal/cholmod_super_numeric', ...
    '../../CHOLMOD/Supernodal/cholmod_super_solve', ...
    '../../CHOLMOD/Supernodal/cholmod_super_symbolic' } ;

cholmod_c_partition_src = {
    '../../CHOLMOD/Partition/cholmod_ccolamd', ...
    '../../CHOLMOD/Partition/cholmod_csymamd', ...
    '../../CHOLMOD/Partition/cholmod_camd', ...
    '../../CHOLMOD/Partition/cholmod_metis', ...
    '../../CHOLMOD/Partition/cholmod_nesdis' } ;

% SuiteSparseQR does not need the MatrixOps or Modify modules of CHOLMOD
%   cholmod_unused = {
%       '../../CHOLMOD/MatrixOps/cholmod_drop', ...
%       '../../CHOLMOD/MatrixOps/cholmod_horzcat', ...
%       '../../CHOLMOD/MatrixOps/cholmod_norm', ...
%       '../../CHOLMOD/MatrixOps/cholmod_scale', ...
%       '../../CHOLMOD/MatrixOps/cholmod_sdmult', ...
%       '../../CHOLMOD/MatrixOps/cholmod_ssmult', ...
%       '../../CHOLMOD/MatrixOps/cholmod_submatrix', ...
%       '../../CHOLMOD/MatrixOps/cholmod_vertcat', ...
%       '../../CHOLMOD/MatrixOps/cholmod_symmetry', ...
%       '../../CHOLMOD/Modify/cholmod_rowadd', ...
%       '../../CHOLMOD/Modify/cholmod_rowdel', ...
%       '../../CHOLMOD/Modify/cholmod_updown' } ;

% SuiteSparseQR source code, and mex support file
spqr_cpp_src = {
    '../Source/spqr_parallel', ...
    '../Source/spqr_1colamd', ...
    '../Source/spqr_1factor', ...
    '../Source/spqr_1fixed', ...
    '../Source/spqr_analyze', ...
    '../Source/spqr_append', ...
    '../Source/spqr_assemble', ...
    '../Source/spqr_cpack', ...
    '../Source/spqr_csize', ...
    '../Source/spqr_cumsum', ...
    '../Source/spqr_debug', ...
    '../Source/spqr_factorize', ...
    '../Source/spqr_fcsize', ...
    '../Source/spqr_freefac', ...
    '../Source/spqr_freenum', ...
    '../Source/spqr_freesym', ...
    '../Source/spqr_front', ...
    '../Source/spqr_fsize', ...
    '../Source/spqr_happly', ...
    '../Source/spqr_happly_work', ...
    '../Source/spqr_hpinv', ...
    '../Source/spqr_kernel', ...
    '../Source/spqr_larftb', ...
    '../Source/spqr_panel', ...
    '../Source/spqr_rconvert', ...
    '../Source/spqr_rcount', ...
    '../Source/spqr_rhpack', ...
    '../Source/spqr_rmap', ...
    '../Source/spqr_rsolve', ...
    '../Source/spqr_shift', ...
    '../Source/spqr_stranspose1', ...
    '../Source/spqr_stranspose2', ...
    '../Source/spqr_trapezoidal', ...
    '../Source/spqr_type', ...
    '../Source/spqr_tol', ...
    '../Source/spqr_maxcolnorm', ...
    '../Source/SuiteSparseQR_qmult', ...
    '../Source/SuiteSparseQR', ...
    '../Source/SuiteSparseQR_expert', ...
    '../MATLAB/spqr_mx' } ;

% SuiteSparse C source code, for MATLAB error handling
spqr_c_mx_src = { '../MATLAB/spqr_mx_error' } ;

% SuiteSparseQR mexFunctions
spqr_mex_cpp_src = { 'spqr', 'spqr_qmult', 'spqr_solve', 'spqr_singletons' } ;

if (pc)
    % Windows does not have drand48 and srand48, required by METIS.  Use
    % drand48 and srand48 in CHOLMOD/MATLAB/Windows/rand48.c instead.
    % Also provide Windows with an empty <strings.h> include file.
    obj_extension = '.obj' ;
    cholmod_c_src = [cholmod_c_src {'../../CHOLMOD/MATLAB/Windows/rand48'}] ;
    include = [include ' -I../../CHOLMOD/MATLAB/Windows'] ;
else
    obj_extension = '.o' ;
end

% compile each library source file
obj = '' ;

c_source = [config_src amd_c_src colamd_c_src cholmod_c_src spqr_c_mx_src ] ;
if (have_metis)
    c_source = [c_source cholmod_c_partition_src ccolamd_c_src ] ;
    c_source = [c_source camd_c_src metis_c_src] ;
end

cpp_source = spqr_cpp_src ;

kk = 0 ;

for f = cpp_source
    ff = f {1} ;
    slash = strfind (ff, '/') ;
    if (isempty (slash))
        slash = 1 ;
    else
        slash = slash (end) + 1 ;
    end
    o = ff (slash:end) ;
    obj = [obj  ' ' o obj_extension] ;                                      %#ok
    s = sprintf ('mex %s -O %s -c %s.cpp', flags, include, ff) ;
    kk = do_cmd (s, kk, details) ;
end

for f = c_source
    ff = f {1} ;
    slash = strfind (ff, '/') ;
    if (isempty (slash))
        slash = 1 ;
    else
        slash = slash (end) + 1 ;
    end
    o = ff (slash:end) ;
    obj = [obj  ' ' o obj_extension] ;                                      %#ok
    s = sprintf ('mex %s -DDLONG -O %s -c %s.c', flags, include, ff) ;
    kk = do_cmd (s, kk, details) ;
end

% compile each mexFunction
for f = spqr_mex_cpp_src
    s = sprintf ('mex %s -O %s %s.cpp', flags, include, f{1}) ;
    s = [s obj ' ' lib] ;                                                   %#ok
    kk = do_cmd (s, kk, details) ;
end

% clean up
s = ['delete ' obj] ;
status = warning ('off', 'MATLAB:DELETE:FileNotFound') ;
delete rename.h
warning (status) ;
do_cmd (s, kk, details) ;
fprintf ('\nSuiteSparseQR successfully compiled\n') ;

%-------------------------------------------------------------------------------
function kk = do_cmd (s, kk, details)
%DO_CMD evaluate a command, and either print it or print a "."
if (details)
    fprintf ('%s\n', s) ;
else
    if (mod (kk, 60) == 0)
        fprintf ('\n') ;
    end
    kk = kk + 1 ;
    fprintf ('.') ;
end
eval (s) ;
