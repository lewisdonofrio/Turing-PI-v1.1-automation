# Builder distcc environment
export PATH="/usr/lib/distcc/bin:/usr/lib/distcc:/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"
export HOSTCC="/usr/bin/gcc"
export HOSTCXX="/usr/bin/g++"
export DISTCC_HOSTS="kubenode2.home.lab/6 kubenode3.home.lab/6 kubenode4.home.lab/6 kubenode5.home.lab/6 kubenode6.home.lab/6 kubenode7.home.lab/6"
