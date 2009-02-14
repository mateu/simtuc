#!/usr/bin/env perl
use strict;
use warnings;
#use lib '/usr/lib/cgi-bin/Tucker';
use lib '/home/hunter/dev/Tucker';
use HTML::Element;
use CGI qw(:header :start_html :end_html :param);
use CGI::Carp qw(fatalsToBrowser);
use Data::Dumper;

# INSTALLATION: configure paths specific to installation, i.e. make them correct paths for your system
my $tmp_path = '/tmp/';
my $examples_path = '/home/hunter/dev/Tucker/examples/';
my $LP_titles = $examples_path . 'LP-titles.txt';

my $qs = $ENV{QUERY_STRING};
my $XHTML_VALIDATOR;
my $EMPTY_STRING = q{};

# If it's a random then write get from tmp path
# otherwise it's a classic example and get it from examples path.
if ( $qs =~ m{mode=load&example=.*&type=random} ) {
    $examples_path = $tmp_path;
}

use View::HTML::Rational;
my $tableau_object = View::HTML::Rational->new;


print header;
print start_html(
					-title=> 'Tucker Tableau Session',
					-style=> '/css/tucker.css',
				);				

# optimize when in optimize mode.
if ( $qs =~ m{session=(.*?)&mode=optimize&row=(\d+)&col=(\d+)} ) {
    my $session = $1;
    my $piv_row_number    = $2;
    my $piv_column_number = $3;
    my $cgi = CGI->new;
    my $is_example = $qs =~ m{example} ? 1 : 0;
    $tableau_object->set_tableau($session, $is_example, $tmp_path, $examples_path);
    print $tableau_object->title_as_HTML;
    if ( $cgi->param('show_tableau') eq 'all' ) {
        $tableau_object->{_html_matrix} = $tableau_object->matrix_as_HTML(0,$session);
        print $tableau_object->tucker_tableau_as_HTML;
    }
    #print "first pivot on: ", $piv_row_number, $piv_column_number;
    $tableau_object->pivot($piv_row_number, $piv_column_number);
    $tableau_object->exchange_pivot_variables($piv_row_number, $piv_column_number);
    
    # pivot until optimal.
    # use counter to exit when caught in BIG loop
    my $counter = 0;
    until ($tableau_object->tableau_is_optimal ) {
        $counter++;
       die "Too many loops" if ($counter > 1000);
        # print each tableau if in trace mode (show_tableau - all)
        if ( $cgi->param('show_tableau') eq 'all' ) {
            $tableau_object->{_html_matrix} = $tableau_object->matrix_as_HTML(0,$session);
            print $tableau_object->tucker_tableau_as_HTML;
        }
        my ($pivot_row_number, $pivot_column_number) = $tableau_object->determine_bland_pivot_row_and_column_numbers;
        #print "now pivoting on: ", $pivot_row_number, $pivot_column_number;
        $tableau_object->pivot($pivot_row_number, $pivot_column_number);
        $tableau_object->exchange_pivot_variables($pivot_row_number, $pivot_column_number);
   }

        $tableau_object->{_html_matrix} = $tableau_object->matrix_as_HTML(1,$session);
        $tableau_object->save_html_tableau_to_file($1, 0, $tmp_path, $examples_path);
        
        print $tableau_object->tucker_tableau_as_HTML;
        print $tableau_object->current_solution_as_HTML($session);

}
# pivot when in pivot mode
elsif ( $qs =~ m{session=(.*?)&mode=pivot&row=(\d+)&col=(\d+)} ) {
    my $session = $1;
    $tableau_object->set_tableau($1, 0, $tmp_path, $examples_path);
    my ($pivot_row_number, $pivot_column_number) = ($2,$3);
    #print "pivoted at: (", $pivot_row_number+1, ",", $pivot_column_number+1, ")<br />\n";
    $tableau_object->pivot($pivot_row_number, $pivot_column_number);
    $tableau_object->exchange_pivot_variables($pivot_row_number, $pivot_column_number);
    $tableau_object->{_html_matrix} = $tableau_object->matrix_as_HTML(1,$1);
    $tableau_object->save_html_tableau_to_file($1, 0, $tmp_path, $examples_path);
    
    print $tableau_object->title_as_HTML;
    print $tableau_object->tucker_tableau_as_HTML;
    print $tableau_object->current_solution_as_HTML($session);
    #print $tableau_object->get_optimize_link($session) if !$tableau_object->is_solution_optimal;
    
}
# load example from file
elsif 	( $qs =~ m{mode=load&example=(.*)} ) {
    
    my $example_file = $1;
    # trim off '&type=random' if necessary
    #print Dumper $example_file;
    $example_file =~ s{&type=random}{};
    #print Dumper $example_file;
    # set random number for temporary session derived from loaded example
    srand;
    my $session = rand;
    
    #print "ready to set tableau";
    $tableau_object->set_tableau($example_file, 1, $tmp_path, $examples_path);
    $tableau_object->{_html_matrix} = $tableau_object->matrix_as_HTML(1,$session);
    $tableau_object->save_html_tableau_to_file($session, 0, $tmp_path, $examples_path);
    
    print $tableau_object->title_as_HTML;
    
    #print $tableau_object->get_html_matrix;
    print $tableau_object->tucker_tableau_as_HTML;
    print $tableau_object->current_solution_as_HTML($session);
    #print $tableau_object->get_optimize_link($session) if !$tableau_object->is_solution_optimal;

}
else {
    
    print $tableau_object->example_list_as_HTML ($LP_titles);
    print "<p>";
    print qq{<a href="/cgi-bin/Tucker/create-LP.cgi">Input</a> a New LP Example<br />};
    print qq{<a href="/cgi-bin/Tucker/create-LP.cgi?mode=return_random_LP">Generate</a> a Random LP };
    print "</p>";
	
}

# if there is a query string then we are not at the home page, thus print home page link
print_home_page_link();
#print_xhtml_validator_link();
print end_html;



####---- subs down under

sub print_home_page_link {
	if ( $ENV{QUERY_STRING} ) {
		my $home_page_url;
		my $a = HTML::Element->new('a', href => $ENV{SCRIPT_NAME});
		$a->push_content( 'Home' );
		my $home_page = $a->as_HTML();
		print '<p>', $home_page, '</p>';
	}	
}

sub print_xhtml_validator_link {
    print "<hr />";
    print $XHTML_VALIDATOR;
}



BEGIN {
												  
use Readonly;
Readonly $XHTML_VALIDATOR => <<'END_VALIDATOR';
<div class="validator">
<a href="http://validator.w3.org/check?uri=referer">
    <img    src="http://www.w3.org/Icons/valid-xhtml10"
                alt="Valid XHTML 1.0 Transitional" height="31" width="88" /></a>
</div>
END_VALIDATOR

}
