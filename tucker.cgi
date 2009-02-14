#!/usr/bin/perl
use strict;
use HTML::Element;
use CGI qw(:header :start_html :end_html :param);
use CGI::Carp qw(fatalsToBrowser);

# INSTALLATION: configure paths specific to installation, i.e. make them correct paths for your system
my $tmp_path = '/tmp/';
my $examples_path = '/var/www/tucker/examples/';
my $LP_titles = $examples_path . 'LP-titles.txt';

my $qs = $ENV{QUERY_STRING};
my $XHTML_VALIDATOR;
my $EMPTY_STRING = q{};

#use Tableau_Float;
use Tableau;
my $tableau_object = Tableau->new;

print header;
print start_html(
							-title=> 'Tucker Tableau Session',
							-style=> '/css/tucker.css',
						)
						;				

# optimize when in optimize mode.
if ( $qs =~ m{session=(.*?)&mode=optimize&row=(\d+)&col=(\d+)} ) {
    my $session = $1;
    my $cgi = CGI->new;
    my $is_example = $qs =~ m{example} ? 1 : 0;
    $tableau_object->set_tableau($session, $is_example, $tmp_path, $examples_path);
    print $tableau_object->get_title_as_HTML;
    if ( $cgi->param('show_tableau') eq 'all' ) {
        $tableau_object->set_html_matrix(0,$session);
        #print $tableau_object->get_html_matrix;
        print $tableau_object->tucker_tableau_as_HTML;
    }
    $tableau_object->pivot($2,$3);
    
    # pivot until optimal.
    # use counter to exit when caught in BIG loop
    my $counter = 0;
    until ($tableau_object->is_solution_optimal ) {
        $counter++;
       die "Too many loops" if ($counter > 1000);
        # print each tableau if in trace mode (show_tableau - all)
        if ( $cgi->param('show_tableau') eq 'all' ) {
            $tableau_object->set_html_matrix(0,$session);
            #print $tableau_object->get_title_as_HTML;
            #print $tableau_object->get_html_matrix;
            print $tableau_object->tucker_tableau_as_HTML;
            #print $tableau_object->current_solution_as_HTML;
        }
        
        my %bland_pivot = $tableau_object->get_bland_simplex_pivot;
        my @bland_pivot = %bland_pivot;
        my @real_pivot = map { $_ + 1 } @bland_pivot;
        #print "pivoting on: ", join ', ', @real_pivot, "<br />\n";
        $tableau_object->pivot($bland_pivot[1]+1, $bland_pivot[0]+1);
   }

        $tableau_object->set_html_matrix(0,$session);
        $tableau_object->save_html_tableau_to_file($1, 0, $tmp_path, $examples_path);
        
        #print $tableau_object->get_html_matrix;
        print $tableau_object->tucker_tableau_as_HTML;
        print $tableau_object->current_solution_as_HTML;

}
# pivot when in pivot mode
elsif ( $qs =~ m{session=(.*?)&mode=pivot&row=(\d+)&col=(\d+)} ) {
    my $session = $1;
    $tableau_object->set_tableau($1, 0, $tmp_path, $examples_path);
    $tableau_object->pivot($2,$3);
    $tableau_object->set_html_matrix(1,$1);
    $tableau_object->save_html_tableau_to_file($1, 0, $tmp_path, $examples_path);
    
    print $tableau_object->get_title_as_HTML;
    print $tableau_object->tucker_tableau_as_HTML;
    print $tableau_object->current_solution_as_HTML;
    #print $tableau_object->get_optimize_link($session) if !$tableau_object->is_solution_optimal;
    
}
# load example from file
elsif 	( $qs =~ m{mode=load&example=(.*)} ) {
    
    # set random number for temporary session derived from loaded example
    srand;
    my $session = rand;
    
    $tableau_object->set_tableau($1, 1, $tmp_path, $examples_path);
    $tableau_object->set_html_matrix(1,$session);
    $tableau_object->save_html_tableau_to_file($session, 0, $tmp_path, $examples_path);
    
    print $tableau_object->get_title_as_HTML;
    
    #print $tableau_object->get_html_matrix;
    print $tableau_object->tucker_tableau_as_HTML;
    print $tableau_object->current_solution_as_HTML($session);
    #print $tableau_object->get_optimize_link($session) if !$tableau_object->is_solution_optimal;

}
else {
    
    print $tableau_object->get_example_list_as_HTML ($LP_titles);
    print "<p>";
    print qq{<a href="/perl/Tucker/create-LP.cgi">Input</a> a New LP Example<br />};
    print qq{<a href="/perl/Tucker/create-LP.cgi?mode=return_random_LP">Generate</a> a Random LP };
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
