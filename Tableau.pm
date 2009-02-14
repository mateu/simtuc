package Tableau;
use strict;
use warnings;
use Math::Cephes::Fraction qw(:fract);
use HTML::TreeBuilder;
use HTML::Element;
use HTML::Table;
use CGI::FormBuilder;
use Data::Dumper;

# TODO Move hardcoded file paths to config file or pass on object instance.
#my $tmp_path = '/tmp/';
#my $examples_path = '/home/hunter/www/html/tucker/examples/';
#my $titles_file = $examples_path . 'LP-titles.txt';


my $_one    = fract( 1, 1 );
my $neg_one = fract( 1, -1 );

# Construct a Tucker Tableau object that contains a tucker tableau matrix
# along with print, convert, decide_pivots and make_pivot methods.
my $EMPTY_STRING = qw{};

sub new {
    my $class = $_[0];
    bless {
        _tableau           => $_[1],
        _number_of_rows    => $_[2],
        _number_of_columns => $_[3],
        _x_variables       => $EMPTY_STRING,
        _y_variables       => $EMPTY_STRING,
        _v_variables       => $EMPTY_STRING,
        _u_variables       => $EMPTY_STRING,
        _html_matrix       => $EMPTY_STRING,
        _title             => $EMPTY_STRING,
    }, $class;
}

sub pivot {

    my $self       = shift;
    my $_pivot_row = shift;
    $_pivot_row -= 1;
    my $_pivot_column = shift;
    $_pivot_column -= 1;

    # Do tucker algebra on pivot row
    my $scale =
      $_one->rdiv( $self->{_tableau}->[$_pivot_row]->[$_pivot_column] );
    for my $j ( 0 .. $self->{_number_of_columns} ) {
        $self->{_tableau}->[$_pivot_row]->[$j] =
          $self->{_tableau}->[$_pivot_row]->[$j]->rmul($scale);
    }
    $self->{_tableau}->[$_pivot_row]->[$_pivot_column] = $scale;

    # Do tucker algebra elsewhere
    for my $i ( 0 .. $self->{_number_of_rows} ) {
        if ( $i != $_pivot_row ) {

            my $neg_a_ic =
              $self->{_tableau}->[$i]->[$_pivot_column]->rmul($neg_one);
            for my $j ( 0 .. $self->{_number_of_columns} ) {
                $self->{_tableau}->[$i]->[$j] =
                  $self->{_tableau}->[$i]->[$j]->radd(
                    $neg_a_ic->rmul( $self->{_tableau}->[$_pivot_row]->[$j] ) );
            }
            $self->{_tableau}->[$i]->[$_pivot_column] = $neg_a_ic->rmul($scale);
        }
    }

    # exchange variables based on $_pivot_column and $_pivot_row
    my $increasing_primal_variable = $self->{_x_variables}->[$_pivot_column];
    my $zeroeing_primal_variable   = $self->{_y_variables}->[$_pivot_row];
    $self->{_x_variables}->[$_pivot_column] = $zeroeing_primal_variable;
    $self->{_y_variables}->[$_pivot_row]    = $increasing_primal_variable;

#print "Primal variable ",  $increasing_primal_variable->{'generic'} , " became dependent (basic) and ",
#   $zeroeing_primal_variable->{'generic'}, " became independent (nonbasic)<br />";

    my $increasing_dual_variable = $self->{_v_variables}->[$_pivot_row];
    my $zeroeing_dual_variable   = $self->{_u_variables}->[$_pivot_column];
    $self->{_v_variables}->[$_pivot_row]    = $zeroeing_dual_variable;
    $self->{_u_variables}->[$_pivot_column] = $increasing_dual_variable;

#print "Dual variable ",  $increasing_dual_variable->{'generic'} , " became dependent (basic) and ",
#    $zeroeing_dual_variable->{'generic'}, " became independent (nonbasic)<br />";

}

sub get_bland_simplex_pivot_as_HTML {
    my $self = shift;
    my (%pivot_for, $html_output);
    if ($self->does_bland_simplex_pivot_exist ) {
        %pivot_for = $self->get_bland_simplex_pivot;
        $html_output = '<div class="pivot"><span class="pivot">Anti-cycling Simplex Pivot:</span><br />';
    	foreach my $pivot_column (sort keys  %pivot_for) {
    	    my $matrix_column = $pivot_column + 1;
    	    my $matrix_row = $pivot_for{$pivot_column} + 1;
            $html_output .= "Bland simplex pivot found in column: "
    		                     . $matrix_column 
    		                     . " row: "
    		                     . $matrix_row 
    		                     .  "<br />\n";	
    	}
        $html_output .= "</div>";
        return $html_output;	
    }
    else {
        return 0;
    }
}

sub set_tableau {
    my ( $self, $session, $is_example, $tmp_path, $examples_path  ) = @_;
    $self->{_session} = $session;
    my $html_tableau = return_html_tableau_from_file( $session, $is_example, $tmp_path, $examples_path  );
    my $_perl_tableau_ref;
    (
        $_perl_tableau_ref,
        $self->{_number_of_rows},
        $self->{_number_of_columns}
      )
      = html_2_perl_tableau($html_tableau);
      

# Make each integer and rational entry a fractional object for rational arthimetic
    for my $i ( 0 .. $self->{_number_of_rows} ) {
        for my $j ( 0 .. $self->{_number_of_columns} ) {

            # Check for existing rationals indicated with "/"
            if ( $_perl_tableau_ref->[$i]->[$j] =~ m{(\-?\d+)\/(\-?\d+)} ) {
                $self->{_tableau}->[$i]->[$j] = fract( $1, $2 );
            }
            else {
                $self->{_tableau}->[$i]->[$j] =
                  fract( $_perl_tableau_ref->[$i]->[$j], 1 );
            }
        }
    }

    $self->set_variable_names($html_tableau);
    $self->set_LP_title($html_tableau);
}

sub variables_as_HTML {
    my $self                     = shift;
    my @variables                = ( 'x', 'y', 'v', 'u' );
    my $variables_as_HTML_string = $EMPTY_STRING;
    foreach my $variable (@variables) {
        $variables_as_HTML_string .= qq{<div name="$variable">} . "\n";
        my $variable_pointer = '_' . $variable . '_variables';
        foreach my $var ( @{ $self->{$variable_pointer} } ) {
            $variables_as_HTML_string .= q{<var>};
            $variables_as_HTML_string .=
              qq{<span name="generic">$var->{'generic'}</span>};
            $variables_as_HTML_string .= qq{<span name="descriptive">$var->{'descriptive'}</span>} if defined $var->{'descriptive'};
            $variables_as_HTML_string .= qq{</var>\n};
        }
        $variables_as_HTML_string .= "</div>\n\n";
    }

    return $variables_as_HTML_string;
}

sub current_solution_as_HTML {
    my $self         = shift;
    my $session   = shift;

    # Report the Current Solution as primal dependents and dual dependents.
    my @x = @{ $self->{_x_variables} };
    my @y = @{ $self->{_y_variables} };
    my @v = @{ $self->{_v_variables} };
    my @u = @{ $self->{_u_variables} };
   
    my $solution_state = $self->is_solution_optimal ? '<span class="optimal">Optimal</span>' : 'Not Optimal';
    
    my $solution_table = new HTML::Table(
        -border  => 0,
        -spacing => 10,
        -padding => 2,
    );
    
    my ($solution_title, $primal_solution, $primal_title);     
    
    $solution_title = "<br />Current Basic Solution - $solution_state\n";
    $solution_table->setCell(1,1 , $solution_title );
    $solution_table->setCellClass( 1, 1, 'title_row' );
    $solution_table->setCellColSpan(1, 1, 2);
    
    
    $primal_title = "Dependent Primal Variables";
    $solution_table->setCell(2,1 , $primal_title );
    
    for my $i ( 0 .. $#y ) {
        if ( $y[$i]->{'descriptive'} ne '' ) {
            $primal_solution .= $y[$i]->{'descriptive'} . " = " .
            $self->{_tableau}->[$i]->[ $self->{_number_of_columns} ]->as_string .
            "<br />\n";
        }
        else {
            $primal_solution .= $y[$i]->{'generic'} 
            . " = " 
            . $self->{_tableau}->[$i]->[ $self->{_number_of_columns} ]->as_string 
            . "<br />\n";
        }
    }
    $solution_table->setCell(3,1 , $primal_solution );
    #$solution_table->setCellVAlign(2,1, 'TOP');
    

    my ($dual_title, $dual_solution);
    $dual_title = "Dependent Dual Variables";
    $solution_table->setCell(2,2 , $dual_title );
     
    for my $j ( 0 .. $#u ) {
        my $var =
          $self->{_tableau}->[ $self->{_number_of_rows} ]->[$j]->rmul($neg_one);
        if ( defined $u[$j]->{'descriptive'} ) {
             $dual_solution .= $u[$j]->{'descriptive'}
                                   . " = "
                                   . $var->as_string 
                                   . "<br />\n";
        }
        else {
              $dual_solution .= $u[$j]->{'generic'}. " = ". $var->as_string ."<br />\n";
        }
    }
    $solution_table->setCell(3,2 , $dual_solution );
    $solution_table->setRowVAlign(3, 'TOP');
    my $independent_variable_notice =
        "By the nature of a <i>basic solution</i>, the primal and dual independent variables	are 0.";
    #$solution_table->setCell(4,1 , $independent_variable_notice );
    #$solution_table->setCellColSpan(4, 1, 2);

    
    $solution_table->setRowHead(1);
    $solution_table->setRowHead(2);
    $solution_table->setRowAlign(1, 'LEFT');
    $solution_table->setRowAlign(2, 'LEFT');
   
    my $bland_pivot_info;
    if ( $self->get_bland_simplex_pivot_as_HTML ) {
         $bland_pivot_info = $self->get_bland_simplex_pivot_as_HTML;
         $bland_pivot_info .= $self->get_optimize_link( $session );
         $solution_table->setCell(4, 1, $bland_pivot_info);
         $solution_table->setCellColSpan(4, 1, 2);
         $solution_table->setRowAlign(4, 'LEFT');
    }
    
    $solution_table->setAlign('CENTER');
     
    return $solution_table;
}

sub set_html_matrix {
    my $self        = shift;
    my $pivot_links = shift;    # 0 = no and 1 = all and 2 = simplex pivots only
    my $session     = shift;
    my $table_width = '100';
    my $table_width_percentage = $table_width . '%';

    #-width   =>  $table_width_percentage,
    my $html_tableau = new HTML::Table(
        -border  => 0,
        -width   => $table_width_percentage,
        -spacing => 0,
        -padding => 2,
    );

    # Determine cell width based on number of columns
    my $cell_width_as_percent_of_table =
      int( $table_width / ( $self->{_number_of_columns} + 1 ) );
    $cell_width_as_percent_of_table .= '%';

# Set data into table cells and decide if a data entry should be hyperlinked to pivot program.
    my %pivot_for;
    if ($pivot_links != 0 ) {
        %pivot_for = $self->get_bland_simplex_pivot();
    }
    foreach my $i ( 0 .. $self->{_number_of_rows} ) {
        my $row = $i + 1;
        foreach my $j ( 0 .. $self->{_number_of_columns} ) {

            my $col    = $j + 1;
            my $_pivot =
                $ENV{SCRIPT_NAME}
              . '?session='
              . $session
              . '&mode=pivot&row='
              . $row . '&col='
              . $col;

# Check to see if entry is a simplex pivot choice and hyperlink it to the pivot method.
            if (   ( exists $pivot_for{$j} )
                && ( $pivot_for{$j} == $i )
                && ( $pivot_links != 0 ) )
            {
                my $a = HTML::Element->new(
                    'a',
                    href  => $_pivot,
                    class => 'nounderline'
                );
                $a->push_content( $self->{_tableau}->[$i]->[$j]->as_string );
                my $_linked_cell = $a->as_HTML();
                $html_tableau->setCell( $i + 1, $j + 1, $_linked_cell );
                $html_tableau->setCellBGColor( $i + 1, $j + 1, '#cccccc' );
            }

# Creat pivot link when in pivot_links = 1, i.e. all and when no in the last row or column
# and the entry is not zero.
            elsif ($pivot_links == 1
                && $i != $self->{_number_of_rows}
                && $j != $self->{_number_of_columns}
                && $self->{_tableau}->[$i]->[$j]->as_string != 0 )
            {
                my $a = HTML::Element->new(
                    'a',
                    href  => $_pivot,
                    class => 'nounderline'
                );
                $a->push_content( $self->{_tableau}->[$i]->[$j]->as_string );
                my $_linked_cell = $a->as_HTML();
                $html_tableau->setCell( $i + 1, $j + 1, $_linked_cell );
            }
            # handling fract and regular number cases separately.  Regular 
            # numbers currently arrise from the examle input form.
            else {
                if ( ref($self->{_tableau}->[$i]->[$j]) eq 'Math::Cephes::Fraction' ) {
                    $html_tableau->setCell( $i + 1, $j + 1,             
                        $self->{_tableau}->[$i]->[$j]->as_string );
                }
                else {
                    $html_tableau->setCell( $i + 1, $j + 1,             
                        $self->{_tableau}->[$i]->[$j] );
                }
            }

            # set css class for last row (objective function of max).
            if ( $i == $self->{_number_of_rows} ) {
                $html_tableau->setCellClass( $i + 1, $j + 1, 'last_row' );
            }
            else {
                $html_tableau->setCellClass( $i + 1, $j + 1,
                    'coefficient_cell' );
            }

            $html_tableau->setCellWidth( $i + 1, $j + 1,
                $cell_width_as_percent_of_table );

        }
    }
    $html_tableau->setLastColClass('last_column');
    $html_tableau->setLastCellClass('last_cell');
    $html_tableau->setClass('matrix');
    $html_tableau->setAlign('center');
    $self->{_html_matrix} = $html_tableau;
}

sub tucker_tableau_as_HTML {
    my $self                   = shift;
    my $table_width            = '100';
    my $table_width_percentage = $table_width . '%';
    my $tucker_tableau         = new HTML::Table(
        -border  => 0,
        -width   => $table_width_percentage,
        -spacing => 0,
        -padding => 2,
    );
    my $n_rows     = $self->{_number_of_rows} + 3;
    my $n_cols     = $self->{_number_of_columns} + 3;
    my $cell_width = int( $table_width / $n_cols );
    $cell_width .= '%';

    # place the x variables in the first row starting at the second column
    # place the u variables in the last row starting in the second column.
    for my $j ( 2 .. $n_cols - 2 ) {
        my $x = $self->{_x_variables}->[ $j - 2 ]->{'descriptive'} ne ''  
                   ? $self->{_x_variables}->[ $j - 2 ]->{'descriptive'}
                   : $self->{_x_variables}->[ $j - 2 ]->{'generic'}
                   ;
        $x =~ s{(.*?)(\d+)$}{<i>$1<sub>$2</sub></i>};

        $tucker_tableau->setCell( 1, $j, $x );
        $tucker_tableau->setCellClass( 1, $j, 'first_tucker_row' );

        my $u =    defined $self->{_u_variables}->[ $j - 2 ]->{'descriptive'}
                   ? $self->{_u_variables}->[ $j - 2 ]->{'descriptive'}
                   : $self->{_u_variables}->[ $j - 2 ]->{'generic'}
                   ;
        $u =~ s{(.*?)(\d+)$}{<i>$1<sub>$2</sub></i>};
        my $cell = "= " . $u;
        $tucker_tableau->setCell( $n_rows, $j, $cell );
        $tucker_tableau->setCellClass( $n_rows, $j, 'last_tucker_row' );
    }

    # place -1 in the first row second to last column
    $tucker_tableau->setCell( 1, $n_cols - 1, '-1' );
    $tucker_tableau->setCellClass( 1, $n_cols - 1, 'first_tucker_row' );

    # place = g in the last row second to last column
    $tucker_tableau->setCell( $n_rows, $n_cols - 1, '= <i>g</i>' );
    $tucker_tableau->setCellClass( $n_rows, $n_cols - 1, 'last_tucker_row' );

    # place the v variables in the first row starting at the second column
    # place the y variables in the last row starting in the second column.
    for my $i ( 2 .. $n_rows - 2 ) {
    
        my $v =    defined $self->{_v_variables}->[ $i - 2 ]->{'descriptive'}
                   ? $self->{_v_variables}->[ $i - 2 ]->{'descriptive'}
                   : $self->{_v_variables}->[ $i - 2 ]->{'generic'}
                   ;
        $v =~ s{(.*?)(\d+)$}{<i>$1<sub>$2</sub></i>};
        $tucker_tableau->setCell( $i, 1, $v );
        $tucker_tableau->setCellClass( $i, 1, 'first_tucker_column' );

        my $y = $self->{_y_variables}->[ $i - 2 ]->{'descriptive'} ne ''
                   ? $self->{_y_variables}->[ $i - 2 ]->{'descriptive'}
                   : $self->{_y_variables}->[ $i - 2 ]->{'generic'}
                   ;
        $y =~ s{(.*?)(\d+)$}{<i>$1<sub>$2</sub></i>};
        my $cell = "= -" . $y;
        $tucker_tableau->setCell( $i, $n_cols, $cell );
        $tucker_tableau->setCellClass( $i, $n_cols, 'last_tucker_column' );
    }

    # place -1 in the first column second to last row
    $tucker_tableau->setCell( $n_rows - 1, 1, '-1' );
    $tucker_tableau->setCellClass( $n_rows - 1, 1, 'first_tucker_column' );

    # place = f in the last column second to last row
    $tucker_tableau->setCell( $n_rows - 1, $n_cols, '= <i>f</i>' );
    $tucker_tableau->setCellClass( $n_rows - 1, $n_cols, 'last_tucker_column' );

    # place the Augmented Matrix table
    $tucker_tableau->setCell( 2, 2, $self->{_html_matrix} );
    $tucker_tableau->setCellColSpan( 2, 2, $n_cols - 2 );
    $tucker_tableau->setCellRowSpan( 2, 2, $n_rows - 2 );

    $tucker_tableau->setClass('tucker');
    $tucker_tableau->setAlign('center');

# set fixed cell width to have proper align (look for percentage alternative for flexibility)
    for my $j ( 1 .. $n_cols ) {
        $tucker_tableau->setCellWidth( 1, $j, $cell_width );
    }

    return $tucker_tableau;

}

sub save_html_tableau_to_file {

# save matrix and variables from which we can reconstruct the full Tucker tableau
    my $self            = shift;
    my $session      = shift;
    my $is_example = shift;
    my $tmp_path    = shift;
    my $examples_path = shift;
    # when loading new examples, make sure the $session does not conflict
    # with existing example file names.
    my $variables    = $self->variables_as_HTML;
    my $session_file;
    if ($is_example) {
        $session_file =
         $examples_path . $session . '.html';
    }
    else {
        $session_file =
         $tmp_path . $session . '.html';
    }
    #my $session_file = '/home/hunter/www/html/tucker/tmp/' . $session . '.html';
    open( F, ">$session_file" )
      or die "Can't open storage file: $session_file for writing\n";
    print F "<title>", $self->{_title}, "</title>\n";
    print F $self->{_html_matrix}, "\n";
    print F $variables;
    close F;

}

####---- helper subroutines
sub html_2_perl_tableau {
    my $_html_tableau = shift;
    my $page_tree     = HTML::TreeBuilder->new_from_content($_html_tableau);
    my @tables        = $page_tree->look_down( _tag => 'table' );
    my $_perl_tableau;

    # Get First Table
    my @rows = $tables[0]->look_down( _tag => 'tr' );
    my $n_rows = $#rows;
    my $n_cols;
    for my $_row ( 0 .. $n_rows ) {
        my @_cells = $rows[$_row]->look_down( _tag => 'td' );
        $n_cols = $#_cells;
        for my $_cell ( 0 .. $n_cols ) {
            $_perl_tableau->[$_row]->[$_cell] =
              $_cells[$_cell]->as_trimmed_text;
        }
    }

    return ( $_perl_tableau, $n_rows, $n_cols );
}

sub set_variable_names {

    # Stepping through each variable of each of the four
    # (primal/dual dependent/independent) categories.
    # Then each of the possibly (currently) two spans
    # for the generic and descriptive variable names.
    my $self          = shift;
    my $_html_tableau = shift;
    my $page_tree     = HTML::TreeBuilder->new_from_content($_html_tableau);
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

sub set_row_and_column_numbers {
    my $self = shift;
    
    my @rows = @{ $self->{_tableau} };
    my $number_of_rows = @rows;
    $number_of_rows -= 1;
    #print "rows: $number_of_rows";
    $self->{_number_of_rows} = $number_of_rows;
    
    my @columns = @{ $self->{_tableau}->[0] };
    my $number_of_columns = @columns;
    $number_of_columns -= 1;
    $self->{_number_of_columns} = $number_of_columns;
    
}

sub set_row_and_column_numbers_explicitly {
    my $self = shift;
    $self->{_number_of_rows} = shift;
    $self->{_number_of_columns} = shift;
}

sub get_row_and_column_numbers {
    my $self = shift;
    return $self->{_number_of_rows}, $self->{_number_of_columns};
}

sub set_generic_variable_names_from_dimensions {
    my $self = shift;
    my (@x, @y, @v, @u);
    for my $i (0..$self->{_number_of_rows}-1) {
        my $tmp_num = $i + 1;
        my $y = 'y' . $tmp_num;
        $self->{_y_variables}->[$i]->{'generic'} = $y;
        my $v = 'v' . $tmp_num;
        $self->{_v_variables}->[$i]->{'generic'} = $v;
    }
    for my $j (0..$self->{_number_of_columns}-1) {
        my $tmp_num = $j + 1;
        my $x = 'x' . $tmp_num;
        $self->{_x_variables}->[$j]->{'generic'} = $x;
        my $u = 'u' . $tmp_num;
        $self->{_u_variables}->[$j]->{'generic'} = $u;
    }
}

# set from stored html tableau
sub set_LP_title {
    my $self          = shift;
    my $_html_tableau = shift;
    my $page_tree     = HTML::TreeBuilder->new_from_content($_html_tableau);
    my $title         = $page_tree->look_down( _tag => 'title' );
    $self->{_title} = $title->as_trimmed_text;

}

# set from string input
sub set_title {
    my $self = shift;
    my $title = shift;
    $self->{_title} = $title;
}
# get from string input
sub get_title {
    my $self = shift;
    return $self->{_title};
}

sub get_title_as_HTML {
    my $self = shift;
    my $output = '<div class="title">' . $self->{_title} . "</div><br />\n";
    return $output;
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

sub min_index {
    my $l = $_[0];
    my $n = @{$l};
    return () unless $n;
    my $v_min = $l->[0];
    my @i_min = (0);

    for ( my $i = 1 ; $i < $n ; $i++ ) {
        if ( $l->[$i] < $v_min ) {
            $v_min = $l->[$i];
            @i_min = ($i);
        }
        elsif ( $l->[$i] == $v_min ) {
            push @i_min, $i;
        }
    }
    return @i_min;

}

sub get_simplex_pivot_columns {
    my $self = shift;
    my @EMPTY_ARRAY = ();
    my @simplex_pivot_columns;
    # According to Nering and Tucker (1993) page 26 
    # "selected a column with a positive entry in the basement row."
    # NOTE: currently I have extended the search for pivot columns to non-negatives.
    # My untution indicates a pivot could still take place but no gains would be made
    # when the cost is zero.  This would not lead us to optimality, but if we were
    # already in an optimal state if may (should) lead to another optimal state.
    # This would only apply then in the optimal case, i.e. all entries non-positive.
    for my $col_num ( 0 .. $self->{_number_of_columns} - 1 ) {
        if ( $self->{_tableau}->[ $self->{_number_of_rows} ]->[$col_num]
            ->as_string > 0 )
        {
            push( @simplex_pivot_columns, $col_num );
        }
    }
    if (@simplex_pivot_columns) {
        #print "there is a simplex pivot column";
        return (\@simplex_pivot_columns);
    }
    else {
        #print "there is not a simplex pivot column";
        return 0;
    }
}

sub does_bland_simplex_pivot_exist {
    my $self = shift;
    
    $self->get_simplex_pivot_columns ? 1 : 0 ;
    
}

sub get_bland_simplex_pivot {
    my $self = shift;
  
    my @simplex_pivot_columns;
    @simplex_pivot_columns =  @{ $self->get_simplex_pivot_columns } if $self->get_simplex_pivot_columns();
    
    # Apply Bland Number Ranking to Colmns.
    my @column_bland_numbers;
    foreach my $col (@simplex_pivot_columns) {
        my $bland_number = $self->get_bland_number_for('u', $col );
        push @column_bland_numbers, $bland_number; 
        #print "col $col has bland: ", $bland_number; 
    }
    my @bland_column = min_index(\@column_bland_numbers);
    my $bland_column = $bland_column[0]; 
    #print "bland column: $bland_column";
    my $bland_pivot_column = $simplex_pivot_columns [ $bland_column  ];
       
# Build Ratios and Choose row(s) that yields min for the bland simplex column as a candidate pivot point.
# To be a Simplex pivot we must not consider negative entries
    my %pivot_for;
    my @ratios;
    my @ratio_rows;

    #print "Column: $possible_pivot_column\n";
    for my $row_num ( 0 .. $self->{_number_of_rows} - 1 ) {
        if ( $self->{_tableau}->[$row_num]->[$bland_pivot_column]
            ->as_string > 0 )
        {
            push(
                @ratios,
                (
                    $self->{_tableau}->[$row_num]
                      ->[ $self->{_number_of_columns} ]->{n} *
                      $self->{_tableau}->[$row_num]->[$bland_pivot_column]
                      ->{d}
                  ) / (
                    $self->{_tableau}->[$row_num]->[$bland_pivot_column]
                      ->{n} * $self->{_tableau}->[$row_num]
                      ->[ $self->{_number_of_columns} ]->{d}
                  )
            );
            # Track the rows that give ratios
            push @ratio_rows, $row_num;
        }
    }
   
    my $ratios_ref    = \@ratios;
    my @min_ratio_rows_index = min_index($ratios_ref);
    # Apply Bland Number Ranking to Rows that tie for minimum ratio.
    my @bland_numbers;
    foreach my $min_ratio_row_index (@min_ratio_rows_index) {
        my $bland_number = $self->get_bland_number_for('y', $min_ratio_row_index );
        push @bland_numbers, $bland_number;
    }
    my @min_bland_number_index = min_index(\@bland_numbers);
    my $min_bland_number_index = $min_bland_number_index[0]; 
    my $bland_pivot_row = $ratio_rows [ $min_ratio_rows_index [ $min_bland_number_index]  ];
    $pivot_for{$bland_pivot_column} =   $bland_pivot_row; 

    @simplex_pivot_columns ? %pivot_for : 0 ;
}

# Given a column number (which represents a u variable) build the bland number from the generic variable name.
sub get_bland_number_for {
            my $self = shift;
            my $variable_type = shift;
            my $variables = '_' . $variable_type . '_variables';
            my $index = shift;
            my $generic_name = $self->{$variables}->[$index]->{'generic'};
            $generic_name =~ m{(.)(\d+)};
            my $var = $1;
            my $num = $2;
            my $start_num = $var eq 'x' ? 1
                                    :  $var eq 'y' ? 2
                                    :  $var eq 'v' ? 4
                                    :  $var eq 'u' ? 3
                                    :  die "Variable name $var does not equal x, y, v or u"
                                    ;
            my $bland_number = $start_num.$num;  
            return $bland_number;
}

sub write_to_tied_title_hash {
    # recall the title hash is tied to a file
    my $self = shift;
    my $example_file = shift;
    my $problem_title = shift;
    my $titles_file = shift;
    
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
    
    #     print $hash{foo};                             # access hash value via key name
    #     $hash{foo} = "bar";                         # assign new value
    #     my @keys = keys %hash;                # get the keys
    #     my @values = values %hash;           # ... and values
    #     exists $hash{perl};                           # check for existence
    #     delete $hash{baz};                           # delete line from file
    #     $hash{newkey} = "perl";                  # entered at end of file
    #     while (($key,$val) = each %hash)     # iterate through hash
    #     untie %hash;                                    # all done
    
}

sub get_tied_title_hash {
    my $self = shift;
    my $titles_file = shift;
#-mxh
#    print Dumper $titles_file;
    use Tie::File::AsHash;
    tie my %titles, 'Tie::File::AsHash', $titles_file, split => ' => '
            or die "Problem tying %titles: $!";
     my %tmp_titles = %titles;
     untie %titles;
     return \%tmp_titles;
}

sub get_example_list_as_HTML {
    my $self = shift;
    my $titles_file = shift;
    my $hash_ref = $self->get_tied_title_hash($titles_file);
   	
	my $example_list = '<h1>Example Linear Programs</h1>';
	
	foreach my $example (sort { $hash_ref->{$a} cmp $hash_ref->{$b} }keys %{$hash_ref}) {
		my $example_url = $ENV{SCRIPT_NAME} . '?mode=load&example='. $example;
		my $a = HTML::Element->new('a', href => $example_url);
		$a->push_content( $hash_ref->{$example} );
		my $linked_example = $a->as_HTML();
		$example_list .= "$linked_example <br />";
	}
    
    return $example_list;
}

sub is_solution_optimal {
    my $self = shift;
    # check basement row for having non-positive entries which would => optimal when in phase 2.
    my $optimal_flag = 1;
    for my $j (0..$self->{_number_of_columns}-1) {
        if ( $self->{_tableau}->[ $self->{_number_of_rows} ]->[$j]->as_string > 0 ) {
            $optimal_flag = 0;
        }
    }
    return $optimal_flag;
}

sub optimize_tableau {
    my $self = shift;
    
    # assume we're coming into optimization from a link 
    # on a non-optimal (but feasible) tableau.  Build the 
    # link as pivot mode link but indicate optimization is desired,
    # i.e. keeping pivoting until optimal.
    
    # NOTE: Optimization code is currently in CGI driver, tucker.cgi

}

sub get_optimize_link {
    my $self = shift;
    my $session = shift;
    my %bland_pivot = $self->get_bland_simplex_pivot;
    my @bland_pivot = %bland_pivot;
    my $col = $bland_pivot[0] + 1;
    my $row  = $bland_pivot[1] + 1;
    my $url = $ENV{SCRIPT_NAME}
                        . '?session='
                        . $session
                        . '&mode=optimize&row='
                        . $row . '&col='
                        . $col;
    
    my $a = HTML::Element->new(
    'a',
    href  => $url,
    class => 'nounderline'
    );
    $a->push_content( 'Optimize' );
    
    my @tableau_views = ('optimal only', 'all');
    my @fields = qw(show_tableau);
    my $form = CGI::FormBuilder->new(
        keepextras => 1,
        method    => 'post',
        fields    => \@fields,
        action => $url,
        submit => 'Optimize',
        table => {class => 'optimize_form'},
        #validate  => { augmented_matrix => 'NUM' },
    );
    
    $form->field(
                    name    => 'show_tableau',
                    options => \@tableau_views,
                    value    => 'optimal only',
                    label     => 'View tableau: ',
                 );
    # return  $a->as_HTML(), 
    return $form->render( header => 0 );
}

sub get_session {
    my $self = shift;
    return $self->{_session};
}


1;
