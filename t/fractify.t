use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Test::More qw( no_plan );

my @fraction_of = (0, 1, 0.5, 0., 1.0);

foreach my $n (@fraction_of) {
  Local::Modulino::DB2JSON->fractify($n);
}
