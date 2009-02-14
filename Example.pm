# A perl module that allows one to add a LPP to be used later
# in a Tucker Tableau session.
package Example;
#use Tableau_Float;
use View::HTML::Float;
use CGI::FormBuilder;
use PDL;
use strict;

# subclassing CGI::Application
use base 'CGI::Application';


sub setup {
    my $self = shift;

    $self->mode_param('mode');
    $self->start_mode('display_form');
    $self->run_modes(
        'display_form'      => 'display_example_input_form',
        'verify_example'    => 'verify_example',
        'process_example'   => 'process_example',
        'return_random_LP'  => 'return_random_LP',
    );
}

# CGI::App builtin for initializing generalities if needed.
sub cgiapp_prerun {

}

sub error {
    my $self  = shift;
    my $error = shift;
    return "An Error has occurred.";

}

# The sub to load the form for LPP input
sub display_example_input_form {

    # Create HTML form with:
    # *  textfield input for LP title.
    # *  textarea input for augmented matrix of initial tableau
    # *  perhaps use default variables with options of descriptive
    # variables on the subsequent page.

    my @fields = qw(problem_title augmented_matrix mode);

    my $form = CGI::FormBuilder->new(
        keepextras => 1,
        method    => 'post',
        fields    => \@fields,
        #validate  => { augmented_matrix => 'NUM' },
        messages => {
                form_required_text      => 'All fields are required',
                js_invalid_start        => 'Submission ERROR',
                js_invalid_input        => 'The %s can not be empty',
                js_invalid_textarea     => 'The "%s" does not contain a perl two-dimensional array.',
                js_invalid_end          => 'Please correct any ERROR to try again.',
                form_invalid_textarea   => 'Error: Input not numbers.',
        },
        required => 'ALL',
    );
    #$form->field('mode') = 'process_example';
    # add options to our mailing list field
    $form->field(
        name => 'augmented_matrix',
        type => 'textarea',
        rows => 12,
        cols => 48,
    );
    $form->field(
        name => 'problem_title',
        size => 32,
    );
    $form->field(
        name => 'mode',
        type => 'hidden',
        value => 'process_example',
    );
    
    return $form->render( header => 0 );
    
}

# Verify the example by checking that we have a perl data structure
# corresponding to an intial tableau.  Allow descriptive variables to be added.
sub verify_example {
    return "verifying example...";
}

# Process the form by building it's example file in the tucker/examples directory
sub process_example {
    my $self = shift;
    #my $tableau = ;
    my $cgi = $self->query();
    my $problem_title =  $cgi->param('problem_title');
    my $augmented_matrix =  $cgi->param('augmented_matrix');
    $augmented_matrix = '$augmented_matrix = ' . $augmented_matrix;
    # TODO Check that augmented_matrix is not tainted, i.e. only contain digits, spaces, commas and [].
    eval $augmented_matrix;
    # TODO Turn numbers into fractional objects.  Currently not necessary, but input must be integer.
    # Make each integer and rational entry a fractional object for rational arthimetic
 
    my $tableau_object = View::HTML::Float->new($augmented_matrix);
    #my $tableau_object = Tableau_Float->new($augmented_matrix);
    $tableau_object ->set_title($problem_title);
    $tableau_object->set_row_and_column_numbers();
    # my $out_tmp = $tableau_object->{_number_of_rows} . " is the number of rows.";
  
    # Builld the example session from the title.  Use this for the file name
    # TODO Check for tainted data
    my $example_file = convert_title_to_file_name($problem_title);
   
    # write example_file name and title out to storage for building examples list.
    # get example file name back (in case it had to be altered to avoid overwriting and existing example.
    $example_file = $tableau_object->write_to_tied_title_hash($example_file, $problem_title, $self->param('LP_titles') );
    
    # set html_matrix needs the params: pivot_links = 0 and session
    $tableau_object->set_html_matrix(0, $example_file);
    
    # we need to set the generic variable names before we can
    # save the LP as an html file
    $tableau_object->set_generic_variable_names_from_dimensions();  
     
    $tableau_object->save_html_tableau_to_file($example_file, 1, $self->param('tmp_path'), $self->param('examples_path') );
   
    # current output just reguerjitates the matrix that were input 
    # and displays the auto generated generic variable names
    my $output  = $tableau_object->{_html_matrix};
         $output .= $tableau_object->variables_as_HTML;
         $output .= get_example_link($example_file, $problem_title);
    return $output;
    
}

sub get_example_link {
    my $example = shift;
    my $title = shift;
    my $example_url = '/cgi-bin/Tucker/tucker_driver.cgi' . '?mode=load&example='. $example;
	my $a = HTML::Element->new('a', href => $example_url);
	$a->push_content( $title );
	my $linked_example = $a->as_HTML();
	return $linked_example;
}

sub get_random_example_link {
    my $example = shift;
    my $title = shift;
    my $example_url = '/cgi-bin/Tucker/tucker_driver.cgi' . '?mode=load&example='. $example . '&type=random';
	my $a = HTML::Element->new('a', href => $example_url);
	$a->push_content( $title );
	my $linked_example = $a->as_HTML();
	return $linked_example;
}

# build a random example on 100 var and coefficient limit
# using integers.  allow contstant to vary over 1000.
sub create_random_tableau_matrix {
    my $self = shift;
    my $max_number_of_rows = shift;
    my $max_number_of_columns = shift;
    my $coefficient_size = shift;
    my $constant_size = shift;
    # defaults
    $max_number_of_rows = 20 if !$max_number_of_rows;
    $max_number_of_columns = 20 if !$max_number_of_columns;
    $coefficient_size = 100  if !$coefficient_size;
    $constant_size = 1000 if !$constant_size;
    my $tableau;
    # first create dimensions
    srand;
    my $number_of_rows = int ($max_number_of_rows * rand);
    my $number_of_columns = int ($max_number_of_columns * rand);
    # iterate over dimensions to set coefficients
    for my $i (0..$number_of_rows-1) {
        for my $j (0..$number_of_columns-1) {
            my $a_ij = int ($coefficient_size * rand);
            $tableau->[$i]->[$j] = $a_ij;
        }
    }
    # set b's
    for my $i (0..$number_of_rows-1) {
        my $constant = int ($constant_size * rand);
        $tableau->[$i]->[$number_of_columns] = $constant;
    }
    # set profit coefficents
    for my $j (0..$number_of_columns-1) {
        my $profit_coefficient = int ($coefficient_size * rand);
        $tableau->[$number_of_rows]->[$j] = $profit_coefficient;
    }
    # set f (and g) equal to 0
    $tableau->[$number_of_rows]->[$number_of_columns] = 0;
    return $tableau;
}

# Process the form by building it's example file in the tucker/examples directory
sub return_random_LP {
    my $self = shift;
    my $random_tableau = $self->create_random_tableau_matrix(20,20,10,10);
    my $tableau_object = View::HTML::Float->new($random_tableau);
    #my $tableau_object = Tableau_Float->new($random_tableau);
    my $session = rand;
    #my $random_example_file = $session . '.html';
    my $problem_title = 'Random LP';
    $tableau_object ->set_title($problem_title);
    
    $tableau_object->set_number_of_rows_and_columns();
    $tableau_object->set_generic_variable_names_from_dimensions();
    $tableau_object->{_html_matrix} = $tableau_object->matrix_as_HTML(0, $session);
    $tableau_object->save_html_tableau_to_file($session, 1, $self->param('tmp_path'), $self->param('examples_path') );
      
    #$tableau_object->set_row_and_column_numbers();
    # set html_matrix needs the params: pivot_links = 0 and session
    #$tableau_object->set_html_matrix(0, $session);
    # we need to set the generic variable names before we can
    # save the LP as an html file
    
    # current output just reguerjitates the matrix that were input 
    # and displays the auto generated generic variable names
    # along with a link to "run" the problem. i.e. apply pivots or optimize directly.
    my $output  = $tableau_object->matrix_as_HTML;
       $output .= $tableau_object->variables_as_HTML;
       $output .= get_random_example_link($session, $problem_title);
    return $output;
    
}


  sub convert_title_to_file_name {
       my $example_file = shift;   # pass the title as the starting string
       # Trim leading and trailing whitespace
       $example_file =~ s{^\s+(.*?)\s+$}{$1}g;
       # Change other spaces to underscores.
       $example_file =~ s{\s+}{_}g;
       # Change hashes into underscores
       $example_file =~ s{\-+}{_}g;
       # Change apostrophies into underscores
       $example_file =~ s{\'+}{-}g;
       $example_file =~ s{\"+}{_}g;
       # Collapse multiple underscores into one
       $example_file =~ s{_+}{_}g;
       use locale;
       $example_file = lc($example_file);
       return $example_file;
        
   }    

# Rules for validating the form on submit.
sub _data_profile {

}


1;
