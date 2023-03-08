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

my %rems;
foreach my $amount (keys %not_wholes) {
  my $i = int($amount);
  my $rem = $amount - $i;
  $rems{$rem}++;
}

print STDERR "there are ", scalar(keys %rems), " distinct remainders\n";
print STDERR Dumper(\%rems);

foreach my $rem (keys %rems) {
  print STDERR "$rem\n";
  my ($h, $k) = Local::Modulino::DB2JSON->fractify($rem, 0.02);
  print STDERR "Fractified: $h/$k\n";
}
exit 1;

my @problematic = (0.625, 0.15, 0.35, 0.13, 0.800000000000011, 0.0499999999999972, 0.875);

# 0.625
# 1: 2 / 3 = 0.6666666666666666 (0.04) ???
# 2: 5 / 8 = 0.625 (0) ???

# 0.15
# 6: 1 / 6 = 0.1666666666666667 (0.02)
# 1: 1 / 7 = 0.1428571428571428 (-0.007)
# Here we definitely don't want 1/7, from the context (there is a whole = 1), we probably want 1/6

# 0.35
# 1: 1 / 3 = 0.3333333333333333 (-0.02)
# 6: 7 / 20 = 0.35 (0)
# Here we don't want 7/20, there is a whole = 1, so probably 1/3 would be best.

# 0.13
# 7: 1 / 7 = 0.1428571428571428 (0.01)
# 1: 1 / 8 = 0.125 (-0.005)
# Here we definitely don't want 1/7, there is no whole, so probably we want 1/8

# 0.800000000000011
# 1: 1 / 1 = 1 (0.2)
# 4: 4 / 5 = 0.8 (-1e-14)
# Here we don't want to fractionize, there is a whole = 226 (226.8)
# but could live with this solution

# 0.0499999999999972
# 20: 1 / 20 = 0.05 (3e-15)
# Here it's an overkill to fractionize, the value we want would be 0.5 -> could exclude divisor 20, the corresponding whole is 85

# 0.875
# 7: 7 / 8 = 0.875 (0)
# weird but ok

### ---> looks ok with approx=0.02
### kept in Python: 2, 3, 4, 5, 6, 8, 10, 16, try the same...


### which divisors should be kept / excluded?

my @fraction_of = (0, 1, 0.5, 0., 1.0, 0.421875, 1.25, 0.333, 0.334, 0.666667);

foreach my $n (@fraction_of) {
  print STDERR "$n\n";
  Local::Modulino::DB2JSON->fractify($n), "\n";
}

foreach my $amount (keys %amounts) {
  print STDERR "$amount\n";
  Local::Modulino::DB2JSON->fractify($amount), "\n";
};

$dbh->disconnect();
