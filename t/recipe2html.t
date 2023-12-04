use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

### generate a html page for a recipe given:
### - the db
### - its id

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::GourmetExport->get_db_handle($database);

my $some_recipe_ids = [qw()];

my $ing_sth = Local::Modulino::GourmetExport->fetch_some_ingredients($dbh, $some_recipe_ids);
my $rec_sth = Local::Modulino::GourmetExport->fetch_some_recipes($dbh, $some_recipe_ids);

my @ing_fields4html = qw(recipe_id item unit amount rangeamount inggroup refid);
my @rec_fields4html = qw(id title instructions modifications cuisine rating description source preptime cooktime servings image link last_modified);


