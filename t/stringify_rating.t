use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

### check how to render ratings from database

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

### first test some imagined ratings

my %test_ratings = (
  '' => [ '',
	  'rating is null'],
  '25' => ['',
	   'rating > 10'],
  '0' => ['',
	  'rating = 0'],
  '4' => ['2/5 Sterne',
	  'rating even'],
  '3' => ['1.5/5 Sterne',
	  'rating odd']
  );


foreach my $rating (keys %test_ratings) {

  my $rating_string = Local::Modulino::GourmetExport->stringify_db_rating($rating);

  is ($rating_string, $test_ratings{$rating}->[0], "input rating: $rating, expected: $test_ratings{$rating}->[0],  $test_rating{$rating}->[1]");

}

### test rating values from db

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::GourmetExport->get_db_handle($database);

my %test_recipe_ids = (
  # recipe ids, the rating strings we expect 0 and test names 1
  '3' => [ '',
	   'db rating is null'],
  '110' => [ '',
	     'db rating = 0'],
  '217' => [ '3/5 Sterne',
	     'db rating is even'],
  '902' => [ '3.5/5 Sterne',
	     'db rating is odd']
  );

my $rating_values = [keys %test_recipe_ids];
my $rating_values_string = join(',', @{ $rating_values });

my $stmt = qq(select id, title, rating from recipe where id in ($rating_values_string););
my $sth = $dbh->prepare($stmt);

$rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
  print $DBI::errstr;
}

while (my ($id, $title, $db_rating) = $sth->fetchrow()) {

  my $rating_string = Local::Modulino::GourmetExport->stringify_db_rating($db_rating);

  is ($rating_string, $test_recipe_ids{$id}->[0], "id $id, rating $test_recipe_ids{$id}->[0],  $test_recipe_ids{$id}->[1]");
  
}

$dbh->disconnect();

# my $stmt = qq(select distinct rating from recipe;);
# my $sth = $dbh->prepare($stmt);

# my $rv = $sth->execute() or die $DBI::errstr;
# if($rv < 0) {
#   print $DBI::errstr;
# }

# print STDERR "Distinct ratings:\n";
# while (my ($db_rating) = $sth->fetchrow()) {
#   print STDERR Local::Modulino::GourmetExport->stringify_db_rating($db_rating), "\n";
# }


# $dbh->disconnect();

