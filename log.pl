#!/usr/bin/perl
use Mojolicious::Lite;

get '/' => sub {
    my $c = shift;
    $c->render(template => 'tail_log_page');
};

websocket '/tail_log' => sub {
    my $c = shift;
    my $file = '/Users/Sachin/workspace/project/mojo_ng/log/production.log';

    $c->inactivity_timeout(300);

    my $pid = open my $log, '-|', 'tail', '-n', 1000, '-f', $file;
    die "Could't spawn: $!" unless defined $pid;

    my $stream = Mojo::IOLoop::Stream->new($log);
    $stream->timeout(300);
    $stream->on(read  => sub { $c->send({text => pop}) });
    $stream->on(close => sub { kill KILL => $pid; close $log });
    my $sid = Mojo::IOLoop->stream($stream);
    $c->on(finish => sub { Mojo::IOLoop->remove($sid) });
};

app->start;

__DATA__
@@ tail_log_window.html.ep
<div id="tail_log_window"></div>
<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>
<script>
    $(document).ready(function (){
        var ws = new WebSocket('<%= url_for('tail_log')->to_abs->scheme('ws') %>');
        var log = document.getElementById('tail_log_window');
        ws.onmessage = function (event) { 
            log.innerHTML += addStyle(event.data);
            $('#tail_log_window').animate({scrollTop: $('#tail_log_window').prop("scrollHeight")}, 500);
        };

        function addStyle (data) {
          var loglevelRe = /\s\[(info|debug|trace|warn|error|fatal)\]\s/i;
          var styled;
          $.each(data.split("\n"), function (i, line) {
            var loglevel = line.match(loglevelRe);
            if(loglevel) {
              styled += '<p class="' + loglevel[1].toLowerCase() + '">' + line + '</p>';
            }else {
              styled += '<p class="default">' + line + '</p>';
            }

          });

          return styled;
        }
    });
</script>
@@ tail_log_page.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title || "@{[app->moniker]} log file" %></title>
    %= stylesheet begin
      #tail_log_window {
        background-color: #232323;
        color: #000;
        padding: 20px;
        overflow: auto;
        height: 900px;
      }

      .info  {color: #428bca}
      .debug {color: #8a6d3b}
      .trace {color: #8a6d3b}
      .warn  {color: #8a6d3b}
      .error {color: #a94442}
      .fatal {color: red}
      .default {color: #blue}
    % end
  </head>
  <body style="overflow: scroll">
    %= include 'tail_log_window'
  </body>
</html>
