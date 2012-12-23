package stealth::swarm;
#ABSTRACT
use Data::Dumper;
use JSON::XS;
use Env qw/PWD/;
use stealth::individual;
$|++;

$SIG{__WARN__} = sub {
  my $message = shift;
  my $prefix = "[$$] [".localtime()."] ";
  $message =~ s/^/$prefix/gm;
 # warn $message;
};

$SIG{__DIE__} = sub {
  my $message = shift;
  my $prefix = "[$$] [".localtime()."] ";
  $message =~ s/^/$prefix/gm;
  die $message;
};

sub generate_task_number_n {
  my $n = shift;
  add_task(sprintf("\ntask%05d", $n), $n,length "xxxxx" x $n);
}

our  $indev = stealth::individual->new();


generate_task_number_n(1);
my $MAX = 100;

my %results;

#	warn "creating doc";
run_queue(
           Trace => 1,
          KidMax => 10,
          KidTask => sub {

            my($key, @values) = @_;
      		my($n, @payload) = @values;

            return  (2 * $n, 2 * $n + 1,encode_json($indev->create()));

          },
          ResultTask => sub {
            my($key, @responses) = @_;

            my($new_2n, $new_2n_plus_1) = @responses;
            if ($results{$key}++) {
              print "DUPLICATE ";

            } else {
              for ($new_2n, $new_2n_plus_1) {
                generate_task_number_n($_) if $_ < $MAX;
              }
            }

            print
              "RESULT for $key => ",
                join(", ",
                     @responses), "\n";
          },
           );

for (sort keys %results) {
#  print "$_ => $results{$_}";
}
    # ABSTRACT: turns baubles into trinkets

use IO::Select;
use IO::Pipe;
use POSIX qw(WNOHANG);
use Storable qw(freeze thaw);
BEGIN {                         # task manager
  my %tasks;                                                                                    

  my @queue;

  sub add_task { ## external
    my $key = shift;
    $tasks{$key} = [@_];
  }

  sub remove_task {
    delete $tasks{+shift};
  }

  sub task_count {
    scalar keys %tasks;
  }

  sub next_task {
    return undef unless task_count() > 0;
    {
      @queue = sort keys %tasks unless @queue;
      my $key = shift @queue;
      redo unless exists $tasks{$key}; # might have disappeared
      freeze([$key, @{$tasks{$key}}]);
    }
  }
}

BEGIN {                         # kid manager
  my %kids;
  my $kid_max = 10;
  my $kid_task;
  my $result_task;
  my $trace = 1;

  sub run_queue { ## external
    {
      my %parms = @_;
      $kid_max = delete $parms{KidMax} if exists $parms{KidMax};
      $kid_task = delete $parms{KidTask} if exists $parms{KidTask};
      $result_task = delete $parms{ResultTask} if exists $parms{ResultTask};
      $trace = delete $parms{Trace} if exists $parms{Trace};
      die "unknown parameters for run_queue: ", join " ", keys %parms
        if keys %parms;
    }

    {
     # warn "to go: ", task_count() if $trace;
      ## reap kids
      while ((my $kid = waitpid(-1, WNOHANG)) > 0) {
       # warn "$kid reaped" if $trace;
        delete $kids{$kid};
      }
      ## verify live kids
      for my $kid (keys %kids) {
        next if kill 0, $kid;
       # warn "*** $kid found missing ***"; # shouldn't happen normally
        delete $kids{$kid};
      }
      ## launch kids
      if (task_count() > keys %kids and
          keys %kids < $kid_max and
          my $kid = create_kid()) {
        send_to_kid($kid, next_task());
      }
      ## see if any ready results
    READY:
      for my $ready (IO::Select->new(map $_->[1], values %kids)->can_read(1)) {
        ## gotta brute force this, grr, good thing data is small...
        my ($kid) = grep $kids{$_}[1] == $ready, keys %kids;
        {
          last unless read($ready, my $length, 4) == 4;
          $length = unpack "L", $length;
          last unless read($ready, my $message, $length) == $length;
          $message = thaw($message) or die "Cannot thaw";
          remove_task($message->[0]);
          $result_task->(@$message);
          if (task_count() >= keys %kids) {
            send_to_kid($kid, next_task());
          } else {              # close it down
            $kids{$kid}[0]->close;
          }
          next READY;
        }
        ## something broken with this kid...
        kill 15, $kid;
        delete $kids{$kid};     # forget about it
      }
      redo if %kids or task_count();
    }
  }

  sub create_kid {
    my $to_kid = IO::Pipe->new;
    my $from_kid = IO::Pipe->new;
    defined (my $kid = fork) or return; # if can't fork, try to make do
    unless ($kid) {             # I'm the kid
      $to_kid->reader;
      $from_kid->writer;
      $from_kid->autoflush(1);
      do_kid($to_kid, $from_kid);
      exit 0;                   # should not be reached
    }
    $from_kid->reader;
    $to_kid->writer;
    $to_kid->autoflush(1);
    $kids{$kid} = [$to_kid, $from_kid];
    $kid;
  }

  sub send_to_kid {
    my ($kid, $message) = @_;
    {
      ## if we get a SIGPIPE here, no biggy, we'll requeue request later
      local $SIG{PIPE} = 'IGNORE';
      print { $kids{$kid}[0] } pack("L", length($message)), $message;
    }
  }

  sub do_kid {
    my($input, $output) = @_;
   # warn "kid launched" if $trace;
    {
      last unless read($input, my $length, 4) == 4;
      $length = unpack "L", $length;
      last unless read($input, my $message, $length) == $length;
      $message = thaw($message) or die "Cannot thaw";
      my ($key, @values) = @$message;
      my @results = $kid_task->($key, @values);
      $message = freeze([$key, @results]);
       print $output pack("L", length($message)), $message;
      redo;
    }
   # warn "kid ending" if $trace;
    exit 0;
  }
}


1;
__DATA__
4663 - 00:12:5a - Microsoft Corporation
5434 - 00:15:5d - Microsoft Corporation
6103 - 00:17:fa - Microsoft Corporation
7605 - 00:1d:d8 - Microsoft Corporation
8741 - 00:22:48 - Microsoft Corporation
9606 - 00:25:ae - Microsoft Corporation
