package Model::Float;
use strict;
use lib '/var/www/cgi-bin/Tucker';
use base 'Model::Generic';

use Readonly;
Readonly my $EPSILON => 1e-14;

my $one     =  1;
my $neg_one = -1;

sub pivot {

    my $self       = shift;
    my $pivot_row_number = shift;
    my $pivot_column_number = shift;

    # Do tucker algebra on pivot row
    my $scale =
      $one / ( $self->{_tableau}->[$pivot_row_number]->[$pivot_column_number] );
    for my $j ( 0 .. $self->{_number_of_columns} ) {
        $self->{_tableau}->[$pivot_row_number]->[$j] =
          $self->{_tableau}->[$pivot_row_number]->[$j] * ($scale);
    }
    $self->{_tableau}->[$pivot_row_number]->[$pivot_column_number] = $scale;

    # Do tucker algebra elsewhere
    for my $i ( 0 .. $self->{_number_of_rows} ) {
        if ( $i != $pivot_row_number ) {

            my $neg_a_ic =
              $self->{_tableau}->[$i]->[$pivot_column_number] * ($neg_one);
            for my $j ( 0 .. $self->{_number_of_columns} ) {
                $self->{_tableau}->[$i]->[$j] =
                  $self->{_tableau}->[$i]->[$j] + (
                    $neg_a_ic * ( $self->{_tableau}->[$pivot_row_number]->[$j] ) );
            }
            $self->{_tableau}->[$i]->[$pivot_column_number] = $neg_a_ic * ($scale);
        }
    }
}


sub tableau_is_optimal {
    my $self = shift;

    # check basement row for having non-positive entries which would => optimal 
    # when in phase 2.  Use EPSILON instead of zero because we're dealing with floats
    my $optimal_flag = 1;
    for my $j ( 0 .. $self->{_number_of_columns}-1 ) {
        if ( $self->{_tableau}->[ $self->{_number_of_rows} ]->[$j] > $EPSILON ) {
            $optimal_flag = 0;
            last;
        }
    }
    return $optimal_flag;
}



sub determine_simplex_pivot_columns {
    my $self = shift;
    
    

    my @simplex_pivot_column_numbers;
    # Assumes the existence of at least one pivot (use optimality check to insure this)
    # According to Nering and Tucker (1993) page 26
    # "selected a column with a positive entry in the basement row."
    # NOTE: My intuition indicates a pivot could still take place but no gains would be made
    # when the cost is zero.  This would not lead us to optimality, but if we were
    # already in an optimal state if may (should) lead to another optimal state.
    # This would only apply then in the optimal case, i.e. all entries non-positive.
    for my $col_num ( 0 .. $self->{_number_of_columns} - 1 ) {
        if ( $self->{_tableau}->[ $self->{_number_of_rows} ]->[$col_num] > $EPSILON )
        {
            push( @simplex_pivot_column_numbers, $col_num );
        }
    }
    return ( @simplex_pivot_column_numbers );
}

sub determine_positive_ratios {
    my $self = shift;
    my $pivot_column_number = shift;
    
# Build Ratios and Choose row(s) that yields min for the bland simplex column as a candidate pivot point.
# To be a Simplex pivot we must not consider negative entries
    my @positive_ratios;
    my @positive_ratio_row_numbers;
    

    #print "Column: $possible_pivot_column\n";
    for my $row_num ( 0 .. $self->{_number_of_rows} - 1 ) {
        if ( $self->{_tableau}->[$row_num]->[$pivot_column_number] > $EPSILON )
        {
            push(
                @positive_ratios,
                    $self->{_tableau}->[$row_num]->[ $self->{_number_of_columns} ]
                    / 
                    $self->{_tableau}->[$row_num]->[$pivot_column_number]
                  );

            # Track the rows that give ratios
            push @positive_ratio_row_numbers, $row_num;
        }
    }

    return (\@positive_ratios, \@positive_ratio_row_numbers);
}


1;
