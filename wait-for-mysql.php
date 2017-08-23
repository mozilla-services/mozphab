#!/usr/bin/env php
<?php
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// This Source Code Form is "Incompatible With Secondary Licenses", as
// defined by the Mozilla Public License, v. 2.0.

// Get unbuffered STDOUT stream
$stdout = fopen('php://stdout', 'w');

$host = getenv('MYSQL_HOST');
$port = getenv('MYSQL_PORT');
$user = getenv('MYSQL_USER');
$pass = getenv('MYSQL_PASS');

$max_tries = 10;
$tries = 0;

fwrite($stdout, "Testing connection to MySQL host '" . $host . ":" . $port . "' as user '" . $user . "'");

while ($tries < $max_tries) {
    $mysql = mysqli_connect($host, $user, $pass, '', $port);

    if (!mysqli_connect_errno()) {
        fwrite($stdout, "\nConnection ready!\n");
        exit(0);
    }

    fwrite($stdout, "Connection not ready. Retrying...");
    $tries++;
    sleep(2);
}

fwrite($stdout, "\nMax tries reached. Connection failed!\n");
exit(1);
?>
