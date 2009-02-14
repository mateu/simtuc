use strict;
use Benchmark;
use PDL;
use Tableau_bones;

=head1 Model Comparison

Benchmark the three models against a number of randomly generated
Linear Programs.

=head1 USAGE

perl benchmark_random_LPs.pl --rows 50 --columns 50 -n 50

=cut


#use Model::Generic;
use Getopt::Long;
use Model::Float;
use Model::PDL;
use Model::Rational;
use Data::Dumper;

GetOptions(
    'rows|r=i'          => \my $rows,
    'columns|c=i'       => \my $columns,
    'number_of_LPs|n=i' => \my $number_of_LPs,
);

srand;
$rows          ||= 20;
$columns       ||= 20;
$number_of_LPs ||= 20;
my $matrix = random_float_matrix( $rows, $columns, 1 );

timethese(
    $number_of_LPs,
    {
        float    => 'solve_LP("float")',
        piddle   => 'solve_LP("piddle")',
        rational => 'solve_LP("rational")',
    }
);

####---- subs below

sub solve_LP {
    my $model   = shift;
    my $tableau = matrix_copy($matrix);

    # extra step for piddles.
    $tableau = pdl $tableau if ( $model eq 'piddle' );

    my $tableau_object =
        $model eq 'float'    ? Model::Float->new($tableau)
      : $model eq 'piddle'   ? Model::PDL->new($tableau)
      : $model eq 'rational' ? Model::Rational->new($tableau)
      :   die "The model type: $model could not be found.";
    $tableau_object->set_number_of_rows_and_columns;
    $tableau_object->set_generic_variable_names_from_dimensions;

    # extra step for rationals (fracts)
    $tableau_object
      ->convert_natural_number_tableau_to_fractional_object_tableau
      if ( $model eq 'rational' );

    my $counter = 1;
    until ( $tableau_object->tableau_is_optimal ) {
        my ( $pivot_row_number, $pivot_column_number ) =
          $tableau_object->determine_bland_pivot_row_and_column_numbers;
        $tableau_object->pivot( $pivot_row_number, $pivot_column_number );
        $tableau_object->exchange_pivot_variables( $pivot_row_number,
            $pivot_column_number );
        $counter++;
        die "Too many loops" if ( $counter > 200 );
    }

}

sub random_float_matrix {

    # code to produce a matrix of random floats (or naturals)
    my $rows    = shift;
    my $columns = shift;
    my $natural_numbers;
    $natural_numbers = 0 unless $natural_numbers = shift;
    my $matrix;
    for my $i ( 0 .. $rows - 1 ) {
        for my $j ( 0 .. $columns - 1 ) {
            $matrix->[$i]->[$j] =
              $natural_numbers == 0 ? rand : int( 10 * rand );
        }
    }

    return $matrix;
}

sub random_pdl_matrix {

    # code to produce a random pdl matrix
    my $rows    = shift;
    my $columns = shift;
    my $matrix  = random( double, $rows, $columns );

    return $matrix;
}

sub matrix_copy {

    # code to copy matrix
    my $matrix = shift;
    my $matrix_copy;

    for my $i ( 0 .. $rows - 1 ) {
        for my $j ( 0 .. $columns - 1 ) {
            $matrix_copy->[$i]->[$j] = $matrix->[$i]->[$j];
        }
    }

    return $matrix_copy;
}
