docker run --rm -v /data/gitlab/jdp:/ws -v ~/.m2:/root/.m2 -v ~/.npm:/root/.npm -v ~/.cache:/root/.cache -v ~/.gradle:/root/.gradle -v ~/.ivy2:/root/.ivy2 -v /tmp:/tmp  --workdir /ws topflow/slaves:trunk-centos-7 bash -l -c "cd jdp-package ; ./gradlew clean clickhouse-rpm"
