use PDL;
use Model::PDL;
use strict;
use Date::Calc qw(Today_and_Now Delta_DHMS);



my $L = [
                [1, 3, 2, 10],
                [2, 1, 1,   8],
                [3, 2, 4,   0],
             ];
             
my $F = [
                [4, 9, 7, 10, 6000],
                [1, 1, 3, 40, 4000],
                [12, 20, 28, 40, 0],
             ];
             
my $W = [
                    [1, 0, 0, -1, 0, 42],
                    [1, 0, 0, 0, -1, 36],
                    [0, 1, 0, -1, 0, 55],
                    [0, 1, 0, 0, -1, 47],
                    [0, 0, 1, -1, 0, 60],
                    [0, 0, 1, 0, -1, 51],
                    [20, 36, 34, -50, -40, 0],
               ];
 
srand;
my $rand_size = 500;
my $one_less = $rand_size - 1;
my $number_of_problems = 1;
my @processing_times;
my @numbers_of_interations;

# test the file write read features of PDL
my $R = random(double, $rand_size, $rand_size);
set $R , $one_less, $one_less,0;
#use PDL::IO::FastRaw;
#writefraw($R, "random_pdl_10000x10000");

for my $i (0..$number_of_problems) {
    solve_random_LP();
}
print "\nAverage Time to process: ";
print average_time_spent_processing(@processing_times), "\n";
print "Average number of iterations: ";
print average_number_of_iterations(@numbers_of_interations), "\n\n";


####---- subs below
sub solve_random_LP {
    my ($year1,$month1,$day1, $hour1,$min1,$sec1) = Today_and_Now();
    my $R = random(double, $rand_size, $rand_size);
    set $R , $one_less, $one_less,0;
    $R *= 1000;

    my $pdl_tableau = PDL_Tableau->new($R);
    $pdl_tableau->set_number_of_rows_and_columns;
    #print $pdl_tableau->get_number_of_rows_and_columns;
    $pdl_tableau->set_generic_variable_names_from_dimensions;
    
    my $counter = 1;
    my $basement_row = $pdl_tableau->{_pdl_tableau}->slice(":,($pdl_tableau->{_number_of_rows})");
    #print "basement row: $basement_row\n";
    while ( $pdl_tableau->is_tableau_not_optimal ) {
        my $pivot_column_number = $pdl_tableau->get_bland_pivot_column;
        my $pivot_row_number = $pdl_tableau->get_bland_pivot_row($pivot_column_number);
        #print "pivot row: $pivot_row_number and pivot column: $pivot_column_number\n";
        $pdl_tableau->pivot_on_pdl($pivot_row_number, $pivot_column_number);
        #print $pdl_tableau->get_pdl;
        $counter++;
        die "blow up" if $counter > 5000;
    }
    
    #print $pdl_tableau->get_pdl;
    $basement_row = $pdl_tableau->{_pdl_tableau}->slice(":,($pdl_tableau->{_number_of_rows})");
    #print "basement row: $basement_row\n";
    my $constant_column = $pdl_tableau->{_pdl_tableau}->slice("($pdl_tableau->{_number_of_columns}),:");
    #print "constant column: $constant_column\n";
    
    my ($year2,$month2,$day2, $hour2,$min2,$sec2) = Today_and_Now();
    my ($delta_days,$delta_hours,$delta_minutes,$delta_seconds) =Delta_DHMS($year1,$month1,$day1, $hour1,$min1,$sec1, $year2,$month2,$day2, $hour2,$min2,$sec2);;
    print "Processing Time:  $delta_hours:$delta_minutes:$delta_seconds in $counter iterations\n"; 
    my $processing_time = 3600*$delta_hours + 60*$delta_minutes + $delta_seconds;
    push @processing_times, $processing_time;
    push @numbers_of_interations, $counter;

}

sub average_time_spent_processing {
    my @processing_times = @_;
    my $number_of_loops = @processing_times;
    my $sum;
    foreach my $time (@processing_times) {
        $sum += $time;
    }
    my $average_processing_time = $sum / @processing_times;
    return sprintf ("%.1f",  $average_processing_time);
}

sub average_number_of_iterations {
    my @numbers_of_interations = @_;
    my $sum;
    foreach my $number_of_iterations (@numbers_of_interations) {
        $sum += $number_of_iterations;
    }
    my $average_number_of_interations = $sum / @numbers_of_interations;
    return sprintf ("%.1f",  $average_number_of_interations);
}
