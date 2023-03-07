use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );


use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);
my $sth = Local::Modulino::DB2JSON->fetch_amounts($dbh);

my %amounts;

while (my ($amount) = $sth->fetchrow()) {

  if ($amount) {
    $amounts{$amount}++;
  }
}

print STDERR "Number of distinct amounts: ", scalar(keys %amounts), "\n";

my %rems;
my %wholes;
my %not_wholes;

use Data::Types qw(:all);


foreach my $amount (keys %amounts) {
  if (is_whole($amount)) {
    $wholes{$amount}++;
  } else {
    $not_wholes{$amount}++;
  }
}

print STDERR "Number of whole amounts: ", scalar(keys %wholes), "\n";
print STDERR "Number of not whole amounts: ", scalar(keys %not_wholes), "\n";

### empty
print STDERR "Testing empty amount: \n";
my $fractified = Local::Modulino::DB2JSON->float_to_frac('', 0.02);
print STDERR "amount empty, fractified: $fractified\n";

### whole amounts

print STDERR "Testing whole amounts: \n";
foreach my $amount (keys %wholes) {
  my $fractified = Local::Modulino::DB2JSON->float_to_frac($amount, 0.02);
  print STDERR "amount: $amount\nfractified: $fractified\n";
}

### amounts between 0 and 1 
my %rems;
foreach my $amount (keys %not_wholes) {
  my $i = int($amount);
  my $rem = $amount - $i;
  $rems{$rem}++;
}

print STDERR "there are ", scalar(keys %rems), " distinct remainders\n";
print STDERR Dumper(\%rems);

print STDERR "Testing amounts between 0 and 1:\n";
foreach my $rem (keys %rems) {
  print STDERR "$rem\n";
  my $fractified = Local::Modulino::DB2JSON->float_to_frac($rem, 0.02);
  print STDERR "Fractified: $fractified\n";
}

print STDERR "Testing non-whole amounts:\n";
foreach my $amount (keys %not_wholes) {
  print STDERR "$amount\n";
  my $fractified = Local::Modulino::DB2JSON->float_to_frac($amount, 0.02);
  print STDERR "Fractified: $fractified\n";
}
