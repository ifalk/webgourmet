use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );

### check how to render source and or links from db
### sometimes source contains links, sometimes these are the same as in the links column

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);

my %test_recipe_ids = (
  # recipe ids, the rating strings we expect 0 and test names 1
  '40' => {
    'source' => [ '', 'db source is null'],
      'link' => [ '', 'db link is null']
  },
  '1248' => {
    'source' => [ '', 'db source is null'],
      'link' => [ 'http://www.nytimes.com/2011/06/28/health/nutrition/28recipehealth.html?_r=2&ref=health', 'db link is not null']
  },
  '3' => {
    'source' => [ 'Maxi Cuisine 19 (sep/oct 2003) p 18', 'db source is not null and not a link'],
      'link' => [ '', 'db link is null' ]
  },
  '1856' => {
    'source' => [ 'Mami', 'db source is not null and not a link'],
      'link' => [ '', 'db link supposed to be not null in sqlite query but looks like it still is'],
  },
  '1824' => {
    'source' => [ 'Jamila Cuisine', 'db source is not null and not a link'],
      'link' => [ 'https://jamilacuisine.ro/saratele-cu-branza-reteta-video/', 'db link not null'],
  },
  '284' => {
    'source' => [ 'http://www.weightwatchers.de/food/rcp/index.aspx?renovate=1&recipeid=117811', 'db source is not null and a link'],
      'link' => [ 'http://www.weightwatchers.de/food/rcp/index.aspx?renovate=1&recipeid=117811', 'db link is null'],
  },
  '1032' => {
    'source' => [ 'http://www.bagelrecipes.net', 'db source is link, different from db link' ],
      'link' => [ 'http://sooishi.blogspot.com/', 'db link is not null and different from db source' ],
  },
  '1078' => {
    'source' => [ '', 'db source is link, same as db link' ],
      'link' => [ 'http://lacuisinedecoralie.blogspot.com/2008/05/banitza.html', 'db link is not null and same as db source' ],
  }
  
  );

my $test_values = [keys %test_recipe_ids];
my $test_values_string = join(',', @{ $test_values });

my $stmt = qq(select id, title, source, link from recipe where id in ($test_values_string););
my $sth = $dbh->prepare($stmt);

$rv = $sth->execute() or die $DBI::errstr;
if($rv < 0) {
  print $DBI::errstr;
}

while (my ($id, $title, $db_source, $db_link) = $sth->fetchrow()) {

  my ($source_string, $link_string) = Local::Modulino::DB2JSON->stringify_source_link($db_source, $db_link);

  is ($source_string, $test_recipe_ids{$id}->{source}->[0], "id $id, source $test_recipe_ids{$id}->{source}->[0],  $test_recipe_ids{$id}->{source}->[1]");

  is ($link_string, $test_recipe_ids{$id}->{link}->[0], "id $id, link $test_recipe_ids{$id}->{link}->[0],  $test_recipe_ids{$id}->{link}->[1]");
}

$dbh->disconnect();
