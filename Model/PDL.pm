package Model::PDL;
use strict;
use lib '/var/www/cgi-bin/Tucker';
use base 'Model::Generic';
use PDL;

####---- subs below

sub pivot {
    my $self = shift;
    my $pivot_row_number = shift;
    my $pivot_column_number =shift;
    
    my $pdl_A = $self->{_tableau};
    my $neg_one = zeroes 1;
    $neg_one -= 1;
    
    my $scale_copy = $pdl_A->slice("($pivot_column_number),($pivot_row_number)")->copy;
    my $scale = $pdl_A->slice("($pivot_column_number),($pivot_row_number)");
    my $pivot_row = $pdl_A->slice(":,($pivot_row_number)");
    $pivot_row /= $scale_copy;
    $scale /= $scale_copy;
    
    # peform pivot algebra in non-pivot rows
    for my $i (0.. $self->{_number_of_rows}) {
        if ( $i != $pivot_row_number) {
            my $a_ic_copy     = $pdl_A->slice("($pivot_column_number),($i)")->copy;
            my $a_ic          = $pdl_A->slice("($pivot_column_number),($i)");
            my $change_row = $pdl_A->slice(":,($i)");
            my $diff_term = $a_ic x $pivot_row;
            $change_row -= $diff_term;
            my $tmp = $neg_one x $a_ic_copy;
            $a_ic .=  $tmp; # $scale_copy;
            $a_ic /= $scale_copy;
        }
    }
    
    return $pdl_A;
}


sub tableau_is_optimal {
    my $self = shift;
    my $T_pdl = $self->{_tableau};
  
    # Look at basement row to see if no positive entries exists.
    my $n_cols_A = $self->{_number_of_columns} - 1;
    my $basement_row = $T_pdl->slice("0:$n_cols_A,($self->{_number_of_rows})");
    my @basement_row = $basement_row->list;
    my @positive_profit_column_numbers;
    my $optimal_flag = 1;
    foreach my $profit_coefficient (@basement_row) {
         if ( $profit_coefficient  > 0 ) {
            $optimal_flag = 0;
            last;
        }
    }
    
    return $optimal_flag;
}

sub determine_simplex_pivot_columns {
    my $self = shift;
    
    my $T_pdl = $self->{_tableau};
    # Look at basement row to see where positive entries exists.
    # Run optimality test first to insure at least one positve profit exists.
    my @simplex_pivot_column_numbers;
    my $n_cols_A = $self->{_number_of_columns} - 1;
    my $basement_row = $T_pdl->slice("0:$n_cols_A,($self->{_number_of_rows})");
    my @basement_row = $basement_row->list;
    my $column_number = 0;
    foreach my $profit_coefficient (@basement_row) {
         if ( $profit_coefficient  > 0 ) {
            push @simplex_pivot_column_numbers, $column_number;
        }
        $column_number++;
    }

    return @simplex_pivot_column_numbers;
}

sub determine_positive_ratios {
    # Starting with the pivot column find the entry that yields the lowest
    # positive b to entry ratio that has lowest bland number in the event of ties.
    my $self = shift;
    my $pivot_column_number = shift;
    
    my $pdl = $self->{_tableau};
    my $n_rows_A = $self->{_number_of_rows} - 1;
    
    my $pivot_column = $pdl->slice("($pivot_column_number),0:$n_rows_A");
    my @pivot_column = $pivot_column->list;
    my $constant_column = $pdl->slice("($self->{_number_of_columns}),0:$n_rows_A");
    my @constant_column = $constant_column->list;
    my $row_number = 0;
    my @positive_ratio_row_numbers;
    my @positive_ratios;
    foreach my $i (0..$n_rows_A) {
        if ( $pivot_column[$i] > 0 ) {
            push @positive_ratios, (  $constant_column[$i] / $pivot_column[$i]);
            push @positive_ratio_row_numbers, $i;
        }
    }
    return (\@positive_ratios, \@positive_ratio_row_numbers);
}


sub get_pdl {
    my $self = shift;
    my $pdl = $self->{_tableau};
    my $output = "$pdl";
    return $output;
}


sub set_number_of_rows_and_columns {
    my $self = shift;
    my ($number_of_columns, $number_of_rows) = $self->{_tableau}->dims;
    ($self->{_number_of_columns},   $self->{_number_of_rows} )= ($number_of_columns - 1, $number_of_rows - 1);

}


1;
