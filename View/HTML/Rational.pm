package View::HTML::Rational;
use strict;
use warnings;
use lib '/home/hunter/dev/Tucker';
#use View::HTML::Generic;
use base 'View::HTML::Generic';
#use Model::Rational;
use base 'Model::Rational';

use Math::Cephes::Fraction qw(:fract);
my $one     = fract( 1,  1 );
my $neg_one = fract( 1, -1 );

use Readonly;
Readonly my $EMPTY_STRING => q();

sub matrix_as_HTML {
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
    my ($pivot_row_number, $pivot_column_number) = $self->determine_bland_pivot_row_and_column_numbers;
    $pivot_for{$pivot_column_number} = $pivot_row_number;
    foreach my $i ( 0 .. $self->{_number_of_rows} ) {
        my $row = $i;
        foreach my $j ( 0 .. $self->{_number_of_columns} ) {

            my $col    = $j;
            my $pivot =
                $ENV{SCRIPT_NAME}
              . '?session='
              . $session
              . '&mode=pivot&row='
              . $row . '&col='
              . $col;

# Check to see if entry is a simplex pivot choice and hyperlink it to the pivot method.
            if (  defined ( $pivot_for{$j}  )
                && ( $pivot_for{$j} == $i )
                && ( $pivot_links != 0 ) )
            {
                my $a = HTML::Element->new(
                    'a',
                    href  => $pivot,
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
                    href  => $pivot,
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
    return $html_tableau;
}


sub current_solution_as_HTML {
    my $self      = shift;
    my $session   = shift;

    # Report the Current Solution as primal dependents and dual dependents.
    my @x = @{ $self->{_x_variables} };
    my @y = @{ $self->{_y_variables} };
    my @v = @{ $self->{_v_variables} };
    my @u = @{ $self->{_u_variables} };
   
    my $solution_state = $self->tableau_is_optimal ? '<span class="optimal">Optimal</span>' : 'Not Optimal';
    
    my $solution_table = new HTML::Table(
        -border     => 0,
        -spacing    => 10,
        -padding    => 2,
    );
    
    my ($solution_title, $primal_solution, $primal_title);     
    
    $solution_title = "<br />Current Basic Solution - $solution_state\n";
    $solution_table->setCell(1,1 , $solution_title );
    $solution_table->setCellColSpan(1, 1, 2);
    $solution_table->setCellClass( 1, 1, 'title_row' );
    
    
    $primal_title = "Dependent Primal Variables";
    $solution_table->setCell(2,1 , $primal_title );
    
    for my $i ( 0 .. $#y ) {
        if ( $y[$i]->{'descriptive'} ne $EMPTY_STRING ) {
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
        if ( $u[$j]->{'descriptive'} ne $EMPTY_STRING ) {
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
        "By the nature of a <i>basic solution</i>, the primal and dual independent variables are 0.";
    $solution_table->setCell(4,1 , $independent_variable_notice );
    $solution_table->setCellColSpan(4, 1, 2);

    
    $solution_table->setRowHead(1);
    $solution_table->setRowHead(2);
    $solution_table->setRowAlign(1, 'CENTER');
    $solution_table->setRowAlign(2, 'LEFT');
   
    my $bland_pivot_info;
    unless ( $self->tableau_is_optimal ) {
         $bland_pivot_info = $self->bland_simplex_pivot_as_HTML;
         $bland_pivot_info .= $self->optimize_link_as_HTML( $session );
         $solution_table->setCell(5, 1, $bland_pivot_info);
         $solution_table->setCellColSpan(5, 1, 2);
         $solution_table->setRowAlign(5, 'LEFT');
    }
    
    $solution_table->setAlign('CENTER');
     
    return $solution_table;
}


1;
