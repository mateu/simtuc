package View::HTML::Generic;
use strict;
use warnings;
use lib '/home/hunter/dev/Tucker';
#use base 'Tableau_bones';
#@Model::Generic::ISA  = qw(Model::Rational Tableau_bones);

#use Math::Cephes::Fraction qw(:fract);
#my $one     = fract( 1,  1 );
#my $neg_one = fract( 1, -1 );

use Readonly;
Readonly my $EMPTY_STRING => q();

use HTML::Element;
use HTML::Table;
use CGI::FormBuilder;




sub bland_simplex_pivot_as_HTML {
    my $self = shift;
    
    #my ($pivot_row_number, $pivot_column_number)             = $self->determine_bland_pivot_row_and_column_numbers;
    my ($bland_pivot_row_number, $bland_pivot_column_number) = $self->determine_bland_pivot_row_and_column_numbers
    or die "Can't determine bland pivot";
    my $bland_row_user_view = $bland_pivot_row_number + 1;
    my $bland_col_user_view = $bland_pivot_column_number + 1;
    my $html_output;
    $html_output = '<div class="pivot"><span class="pivot">Anti-cycling Simplex Pivot:</span><br />';
    $html_output .= "Bland simplex pivot found in column: "
                 . $bland_col_user_view
                 . " row: "
                 . $bland_row_user_view
                 .  "<br />\n";	
    $html_output .= "</div>";

    return $html_output;	
}

sub example_list_as_HTML {
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

sub title_as_HTML {
    my $self = shift;
    my $output = '<div class="title">' . $self->{_title} . "</div><br />\n";
    return $output;   
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
        my $x = $self->{_x_variables}->[ $j - 2 ]->{'descriptive'} ne $EMPTY_STRING 
                   ? $self->{_x_variables}->[ $j - 2 ]->{'descriptive'}
                   : $self->{_x_variables}->[ $j - 2 ]->{'generic'}
                   ;
        $x =~ s{(.*?)(\d+)$}{<i>$1<sub>$2</sub></i>};

        $tucker_tableau->setCell( 1, $j, $x );
        $tucker_tableau->setCellClass( 1, $j, 'first_tucker_row' );

        my $u = $self->{_u_variables}->[ $j - 2 ]->{'descriptive'} ne $EMPTY_STRING 
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
    
        my $v = $self->{_v_variables}->[ $i - 2 ]->{'descriptive'} ne $EMPTY_STRING 
                   ? $self->{_v_variables}->[ $i - 2 ]->{'descriptive'}
                   : $self->{_v_variables}->[ $i - 2 ]->{'generic'}
                   ;
        $v =~ s{(.*?)(\d+)$}{<i>$1<sub>$2</sub></i>};
        $tucker_tableau->setCell( $i, 1, $v );
        $tucker_tableau->setCellClass( $i, 1, 'first_tucker_column' );

        my $y = $self->{_y_variables}->[ $i - 2 ]->{'descriptive'} ne $EMPTY_STRING 
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
              qq{<span name="generic">$var->{'generic'}</span>} .
              qq{<span name="descriptive">$var->{'descriptive'}</span>};
            $variables_as_HTML_string .= qq{</var>\n};
        }
        $variables_as_HTML_string .= "</div>\n\n";
    }

    return $variables_as_HTML_string;
}



sub optimize_link_as_HTML {
    my $self = shift;
    my $session = shift;
    
    # Get bland pivot row and column number
    my ($row, $col) = $self->determine_bland_pivot_row_and_column_numbers;
    
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
    #return  $a->as_HTML(), 
    return $form->render( header => 0 );
}






1;
