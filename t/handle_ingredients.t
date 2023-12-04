use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';

my $dbh = Local::Modulino::GourmetExport->get_db_handle($database);


my $ing_sth = Local::Modulino::GourmetExport->fetch_some_ingredients($dbh);

####

my $ing_list = $ing_sth->fetchrow_hashref();

while (my $ing_list = $sth->fetchrow_hashref()) {
  next if ($ing_list->{deleted});

  my $recipe_id = $ing_list->{recipe_id};

  my $item = $ing_list->{item};

  my $ing_group = $class->handle_inggroup($ing_list->{inggroup});

							       }

