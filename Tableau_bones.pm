package Tableau_bones;
use strict;
use warnings;
use lib '/home/hunter/dev/Tucker';
#use lib '/home/hunter/www/cgi-bin/Tucker';
use Math::Cephes::Fraction qw(:fract);
use HTML::TreeBuilder;
use Data::Dumper;


# Construct a Tucker Tableau object that contains a tucker tableau matrix
# along with print, convert, decide_pivots and make_pivot methods.

sub new {
    my $class = $_[0];
    bless {
        _tableau           => $_[1],
        _number_of_rows    => $_[2],
        _number_of_columns => $_[3],
        _x_variables       => undef,
        _y_variables       => undef,
        _v_variables       => undef,
        _u_variables       => undef,
        _html_matrix       => undef,
        _title             => undef,
    }, $class;
}



sub set_tableau {
    my ( $self, $session, $is_example, $tmp_path, $examples_path  ) = @_;
    
    my $html_tableau = return_html_tableau_from_file( $session, $is_example, $tmp_path, $examples_path  );
    my ($string_matrix, $number_of_rows, $number_of_columns) = get_string_matrix_and_dimensions_from($html_tableau);
    $self->set_row_and_column_numbers($number_of_rows, $number_of_columns);   
    # Which model are we working with.
    # print "ref object is: ", ref($self), "\n";
    if ( ref($self) =~ m{Rational}  ) {  
        $self->string_matrix_to_fract_matrix($string_matrix); 
    }
    else {
        $self->string_matrix_to_float_matrix($string_matrix); 
    }
    $self->set_variable_names_from($html_tableau);
    $self->set_LP_title_from($html_tableau);
}



sub save_html_tableau_to_file {
    # Save matrix and variables from which we can reconstruct the full Tucker tableau
    my $self            = shift;
    my $session         = shift;
    my $is_example      = shift;
    my $tmp_path        = shift;
    my $examples_path   = shift;
    
    # When loading new examples, make sure the $session does not conflict
    # with existing example file names.
    my $session_file = $is_example ? $examples_path . $session . '.html'
                       : $tmp_path . $session . '.html'
                       ;
                       
    open( F, ">$session_file" )
      or die "Can't open storage file: $session_file for writing\n";
    print F $self->title_as_HTML,           "\n";
    print F $self->matrix_as_HTML,       "\n";
    print F $self->variables_as_HTML,   "\n";
    close F;

}

####---- helper subroutines
sub get_string_matrix_and_dimensions_from {
    my $html_tableau = shift;
    my $page_tree     = HTML::TreeBuilder->new_from_content($html_tableau);
    my @tables        = $page_tree->look_down( _tag => 'table' );
    my $string_matrix;

    # Get First Table
    my @rows = $tables[0]->look_down( _tag => 'tr' );
    my $n_rows = $#rows;
    my $n_cols;
    for my $row ( 0 .. $n_rows ) {
        my @cells = $rows[$row]->look_down( _tag => 'td' );
        $n_cols = $#cells;
        for my $cell ( 0 .. $n_cols ) {
            $string_matrix->[$row]->[$cell] =
              $cells[$cell]->as_trimmed_text;
        }
    }

    return ( $string_matrix, $n_rows, $n_cols );
}

sub set_variable_names_from {

    # Stepping through each variable of each of the four
    # (primal/dual dependent/independent) categories.
    # Then each of the possibly (currently) two spans
    # for the generic and descriptive variable names.
    my $self          = shift;
    my $html_tableau = shift;
    my $page_tree     = HTML::TreeBuilder->new_from_content($html_tableau);
    my @divs          = $page_tree->look_down( _tag => 'div' );
    foreach my $div (@divs) {

        #print "div encountered...";
        my $variable_type                = $div->attr('name');
        my $variable_string              = '_' . $variable_type . '_variables';
        my $occurrences_of_variable_type = 0;
        my @vars                         = $div->look_down( _tag => 'var' );

        #print "var encountered...";
        foreach my $var (@vars) {
            my @spans = $var->look_down( _tag => 'span' );
            foreach my $span (@spans) {

                #print "span encounter";
                if ( $span->attr('name') eq 'generic' ) {
                    $self->{$variable_string}->[$occurrences_of_variable_type]
                      ->{'generic'} = $span->as_trimmed_text;

                    #print  $span->as_trimmed_text;
                }
                if ( $span->attr('name') eq 'descriptive' ) {
                    $self->{$variable_string}->[$occurrences_of_variable_type]
                      ->{'descriptive'} = $span->as_trimmed_text;
                }
            }

            $occurrences_of_variable_type++;

        }

    }

}


# set from stored html tableau
sub set_LP_title_from {
    my $self          = shift;
    my $html_tableau  = shift;
    my $page_tree     = HTML::TreeBuilder->new_from_content($html_tableau);
    my @divs          = $page_tree->look_down( _tag => 'div' );
    my $title;
    foreach my $div (@divs) {
        $title = $div if $div->attr('class') eq 'title';
    }
    $self->{_title}   = $title->as_trimmed_text;
}

sub set_row_and_column_numbers {
    my $self = shift;
    $self->{_number_of_rows} = shift;
    $self->{_number_of_columns} = shift;
}

# set from string input
sub set_title {
    my $self = shift;
    my $title = shift;
    $self->{_title} = $title;
}


sub return_html_tableau_from_file {

    my $session            = shift;
    my $is_example      = shift;
    my $tmp_path         = shift;
    my $examples_path = shift;
    my $session_file;
    if ($is_example) {
        $session_file =
         $examples_path . $session . '.html';
    }
    else {
        $session_file =
         $tmp_path. $session . '.html';
    }
    open( F, "$session_file" )
      or die "Can't open storage file: $session_file for reading\n";
    my $table;
    while (<F>) {
        $table .= $_;
    }
    close F;

    return ($table);
}


sub write_to_tied_title_hash {
    # recall the title hash is tied to a file
    my $self            = shift;
    my $example_file    = shift;
    my $problem_title   = shift;
    my $titles_file     = shift;
    
    use Tie::File::AsHash;
    tie my %titles, 'Tie::File::AsHash', $titles_file, split => ' => '
            or die "ERROR: Problem tying %titles: does the titles file, $titles_file have a problem? ERROR: $!";
            
     if ( exists $titles{$example_file} ) {
        # file name already exists, append a random number to create a unique one.
        srand;
        my $random_number = rand;
        $example_file .= "_$random_number";
     }
     # assign title to file_name
     $titles{$example_file} = $problem_title;
     # write out to file
     untie %titles;
     # return the file_name in case it was changed to avoid overwriting already existing example file
     
     return $example_file;
}

sub get_tied_title_hash {
    my $self = shift;
    my $titles_file = shift;
#-mxh
#print Dumper $titles_file;
    use Tie::File::AsHash;
    tie my %titles, 'Tie::File::AsHash', $titles_file, split => ' => '
            or die "Problem tying %titles: $!";
     my %tmp_titles = %titles;
     untie %titles;
     return \%tmp_titles;
}

sub string_matrix_to_fract_matrix {
    #print "string to fract";
    my $self = shift;
    my $string_matrix = shift;
    # Make each integer and rational entry a fractional object for rational arthimetic
    for my $i ( 0 .. $self->{_number_of_rows} ) {
        for my $j ( 0 .. $self->{_number_of_columns} ) {
            
            # Check for existing rationals indicated with "/"
            if ( $string_matrix->[$i]->[$j] =~ m{(\-?\d+)\/(\-?\d+)} ) {
                $self->{_tableau}->[$i]->[$j] = fract( $1, $2 );
                
            }
            else {
                $self->{_tableau}->[$i]->[$j] =
                  fract( $string_matrix->[$i]->[$j], 1 );
            }
        }
    }
}

sub string_matrix_to_float_matrix {
    my $self = shift;
    my $string_matrix = shift;
    # Make each integer and rational entry a fractional object for rational arthimetic
    for my $i ( 0 .. $self->{_number_of_rows} ) {
        for my $j ( 0 .. $self->{_number_of_columns} ) {
    
                # Check for existing rationals indicated with "/"
            if ( $string_matrix->[$i]->[$j] =~ m{(\-?\d+)\/(\-?\d+)} ) {
                $self->{_tableau}->[$i]->[$j] = $1 / $2;
            }
            else {
                $self->{_tableau}->[$i]->[$j] = $string_matrix->[$i]->[$j];
            }
        }
    }
}

sub float_matrix_to_pdl_matrix {
	my $self = shift;
	
}

1;
