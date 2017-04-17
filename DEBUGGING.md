Setting up docker
-----------------

Put dns settings to the `/etc/default/docker`

     DOCKER_OPTS="--dns=<SOME-PRIVATE-DNS-SERVER --dns=8.8.8.8"


Put docker on the port
----------------------

     sudo apt-get install socat
     sudo socat TCP-LISTEN:4243,fork,bind=127.0.0.1 UNIX:/var/run/docker.sock

or

     sudo docker stop
     sudo docker -d -H localhost:4243 &
