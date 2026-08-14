package DPDA::Controller::Quiz;

use Mojo::Base 'Mojolicious::Controller', -signatures;

use GD;
use GD::Graph::bars;
use Statistics::Frequency;

use constant QUESTION_FILE => 'dpda-questions.txt';
use constant RESPONSES     => 10;

=head1 NAME

DPDA::Controller::Quiz - Routes for the personality-disorder quiz

=head1 ROUTES

=head2 index

C<GET /> - redirect to the overview page.

=cut

sub index ($self) {
    $self->redirect_to('overview');
}

=head2 overview

C<GET /overview> - the informational overview page.

=cut

sub overview ($self) {
    $self->render(template => 'quiz/overview', title => 'Overview - DPDA');
}

=head2 sample

C<GET /sample> - a sample results page.

=cut

sub sample ($self) {
    $self->render(template => 'quiz/sample', title => 'Sample Results - DPDA');
}

=head2 question

C<GET /question> - show the next unanswered question.

=cut

sub question ($self) {
    my $progress = $self->param('progress') || 1;

    # Starting over: clear any history left in the session
    $self->session(history => {}) if $progress == 1;

    my $history = $self->session('history') || {};
    my @quiz    = $self->_load_quiz;

    return $self->redirect_to('chart') if keys(%$history) >= @quiz;

    my ($question_num, $question_text) = $self->_next_question(\@quiz, $history);

    $self->render(
        template        => 'quiz/question',
        title           => 'Question - DPDA',
        question_num    => $question_num,
        question_text   => $question_text,
        progress        => $progress,
        total_questions => scalar(@quiz),
    );
}

=head2 submit

C<POST /quiz> - record an answer and move on to the next question
(or the results chart, if this was the last one).

=cut

sub submit ($self) {
    my $question = $self->param('question');
    my $answer   = $self->param('answer');
    my $progress = ($self->param('progress') || 1) + 1;

    my $history = $self->session('history') || {};
    $history->{$question} = $answer if length($answer // '');
    $self->session(history => $history);

    my @quiz = $self->_load_quiz;

    return $progress > @quiz
        ? $self->redirect_to('chart')
        : $self->redirect_to($self->url_for('question')->query(progress => $progress));
}

=head2 chart

C<GET /chart> - tally the results and render the results chart.

=cut

sub chart ($self) {
    my $history = $self->session('history') || {};
    my @quiz    = $self->_load_quiz;

    my (%order, %results, %discord, %number);

    $self->_calc_results(\@quiz, RESPONSES, $history, \%results, \%discord);
    $self->_order_category(\%order, \@quiz);

    for my $category (keys %results) {
        $number{$category} = grep { /^\Q$category\E\b/ } @quiz;
    }

    my %average = map { $_ => $results{$_} / $number{$_} } keys %results;

    my %norm_discord =
        map { $_ => (RESPONSES * $discord{$_} / ($number{$_} / 2)) / (RESPONSES - 1) }
        keys %discord;

    my %diff = map { $_ => $average{$_} - $norm_discord{$_} } keys %average;

    my $freq = Statistics::Frequency->new(\%diff);
    my %prop = $freq->proportional_frequencies;

    # Format for display
    %average      = map { $_ => sprintf('%.3f', $average{$_}) } keys %average;
    %norm_discord = map { $_ => sprintf('%.3f', $norm_discord{$_}) } keys %norm_discord;
    %diff         = map { $_ => sprintf('%.3f', $diff{$_}) } keys %diff;
    %prop         = map { $_ => sprintf('%.3f', $prop{$_}) } keys %prop;

    my $chart = $self->_draw_chart(RESPONSES, \%order, \%average, \%norm_discord);

    $self->render(
        template => 'quiz/chart',
        title    => 'Your Results - DPDA',
        order    => \%order,
        average  => \%average,
        discord  => \%norm_discord,
        diff     => \%diff,
        prop     => \%prop,
        chart    => $chart,
    );
}

=head1 PRIVATE METHODS

=cut

# Read the question bank fresh on every call. It's a small text file,
# so the cost is negligible - and unlike a `state`-cached version, this
# always reflects the current contents of the file on disk (no need to
# restart the app after editing dpda-questions.txt).
sub _load_quiz ($self) {
    my $file = $self->app->home->child('public', QUESTION_FILE);

    die "Can't read $file: question file not found\n" unless -e $file;

    my @quiz = $file->slurp =~ /^(.+)$/mg;

    return @quiz;
}

sub _next_question ($self, $questions, $history) {
    my $x = keys %$history;
    my $y = @$questions;
    die "History equal to number of questions: $x >= $y\n"
        if $x >= $y;

    my $question_num;
    do {
        $question_num = int rand @$questions;
    } while exists $history->{$question_num};

    my $question_text = (split /\|/, $questions->[$question_num])[1];

    return ($question_num, $question_text);
}

sub _calc_results ($self, $quiz, $responses, $history, $results, $discord) {
    for my $key (sort { $a <=> $b } keys %$history) {
        # Questions are asked in +/- pairs; only look at the "odd" half
        # of each pair so each pair is processed exactly once.
        next unless $key % 2;

        my $val = $history->{ $key - 1 };
        my ($category, undef, $inv) = split /\s+/, (split /\|/, $quiz->[ $key - 1 ])[0];
        $val = $self->_invert_neg($responses, $inv, $val);
        $results->{$category} += $val;

        my $next  = $history->{$key};
        my $inv2  = (split /\s+/, (split /\|/, $quiz->[$key])[0])[-1];
        $next     = $self->_invert_neg($responses, $inv2, $next);
        $results->{$category} += $next;

        $discord->{$category} += abs($val - $next);
    }
}

sub _invert_neg ($self, $size, $flag, $val) {
    return $flag eq '-' ? $size - ($val - 1) : $val;
}

sub _order_category ($self, $order, $quiz) {
    my $next = 1;

    for my $line (@$quiz) {
        my ($category) = $line =~ /^(\w+)/;
        $order->{$category} //= $next++;
    }
}

sub _draw_chart ($self, $size, $order, $results, $discord) {
    my $graph = GD::Graph::bars->new(700, 600);
    $graph->set(
        title         => 'Results',
        x_label       => 'Categories',
        y_label       => 'Value',
        y_max_value   => $size,
        y_tick_number => $size,
        y_label_skip  => 1,
        x_labels_vertical => 1,
        textclr           => 'black',
        labelclr          => 'black',
        axislabelclr      => 'black',
        legendclr         => 'black',
    ) or die 'Can\'t set graph: ' . $graph->error;

    $graph->set_title_font(GD::gdGiantFont);
    $graph->set_x_label_font(GD::gdMediumBoldFont);
    $graph->set_y_label_font(GD::gdMediumBoldFont);
    $graph->set_x_axis_font(GD::gdMediumBoldFont);
    $graph->set_y_axis_font(GD::gdMediumBoldFont);
    $graph->set_legend_font(GD::gdMediumBoldFont);

    my @names   = sort { $order->{$a} <=> $order->{$b} } keys %$order;
    my @results = map { $results->{$_} } @names;
    my @discord = map { $discord->{$_} } @names;
    @names      = map { ucfirst $_ } @names;

    my $gd = $graph->plot([ \@names, \@results, \@discord ])
        or die $graph->error;

    my $dir = $self->app->home->child('public', 'charts');
    $dir->make_path unless -d $dir;

    my $filename = 'dpda-' . time . '.png';
    $dir->child($filename)->spew($gd->png);

    return "charts/$filename";
}

1;
