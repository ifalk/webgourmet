use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );


use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);

my %test_amounts = (
  '27' => 'whole amount',
  '17' => 'not whole amount',
  '22' => 'float, to be fractified',
  '1307' => 'float, not to be fractified, rounded',
  '1879' => 'with rangeamount, wholes',
  '1863' => 'with rangeamount, with amounts to be fractified',
  '1732' => 'with rangeamount, with amounts to be fractified',
  '1431' => 'with rangeamount, with amounts to be fractified',
  '1434' => 'with rangeamount, where rangeamount>amount',
  '1503' => 'with rangeamount, where rangeamount<amount'
  );



my $sth = Local::Modulino::DB2JSON->fetch_some_ingredients($dbh, [keys %test_amounts]);

my %amounts;

while (my $ing = $sth->fetchrow_hashref()) {

  my $recipe_id = $ing->{recipe_id};
  my $item_id = $ing->{id};
  foreach my $field (qw(item amount rangeamount)) {
    $amounts{$recipe_id}->{$item_id}->{$field} = $ing->{$field};
  }
}

foreach my $recipe_id (keys %amounts) {
  print STDERR "Recipe id: $recipe_id, $test_amounts{$recipe_id}\n";
  foreach my $item_id (keys %{ $amounts{$recipe_id} }) {
    print STDERR "   item id: $item_id\n";
    my $db_amount = $amounts{$recipe_id}->{$item_id}->{'amount'};
    my $db_rangeamount = $amounts{$recipe_id}->{$item_id}->{'rangeamount'};

    my $astring = Local::Modulino::DB2JSON->stringify_amounts($db_amount, $db_rangeamount);
    print STDERR "      amount/rangeamount string: $astring\n";
  }
}

$dbh->disconnect();
