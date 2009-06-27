use inc::Module::Install;

name 'SimTuc';
all_from 'lib/MojoMojo.pm';

requires(
    'Algorithm::Diff'                              => '1.1901',
    'Algorithm::Merge'                             => 0,
    'Algorithm::IncludeExclude'                    => 0,
    'Archive::Zip'                                 => '1.14',
    'MRO::Compat'                                  => '0.10',
    'Cache::FastMmap'                              => 0,
    );