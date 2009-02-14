#!/usr/bin/env perl
use strict;
use CGI::Carp qw(fatalsToBrowser);
use Example;

# INSTALLATION: configure paths specific to installation, 
# i.e. make them correct paths for your system
my $tmp_path = '/tmp/';
#my $examples_path = '/home/hunter/dev/Tucker/examples/';
my $examples_path = $tmp_path;
my $LP_titles = $examples_path . 'LP-titles.txt';

my $LP_example = 
    Example->new( 
                             PARAMS => {
                                                    tmp_path => $tmp_path,
                                                    examples_path => $examples_path,
                                                    LP_titles => $LP_titles,
                                                 } 
                           );
                           
$LP_example->run();


