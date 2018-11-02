# This docker file builds a base image for laoding OLS data, this image itself does not run the OLS server or deal with loading data
# to see and example of a Dockerfile for loading ontologies and running a local OLS server checkout https://github.com/HumanCellAtlas/ontology/blob/master/Dockerfile

FROM alpine:3.7

ENV PACKAGES bash mongodb openjdk8
ENV TERM=linux

RUN apk update && apk upgrade && \
    apk add $PACKAGES --no-cache && \
    rm -rf /var/cache/apk/*

ENV OLS_HOME /opt/ols
ENV JAVA_OPTS "-Xmx8g"
ENV SOLR_VERSION 5.5.3

#ADD ols-web/src/main/resources/ols-config.yaml ${OLS_HOME}

RUN mkdir -p ${OLS_HOME}

#ADD ols-web/target/ols-boot.war  ${OLS_HOME}
ADD ols-apps/ols-config-importer/target/ols-config-importer.jar ${OLS_HOME}
ADD ols-apps/ols-loading-app/target/ols-indexer.jar ${OLS_HOME}
ADD ols-solr/src/main/solr-5-config ${OLS_HOME}/solr-5-config

## Prepare configuration files
ADD ols-web/src/main/resources/ols-config.yaml ${OLS_HOME}
ADD ols-web/src/main/resources/application.properties ${OLS_HOME}
#ADD ols-web/src/main/resources/ols-config.yaml ${OLS_HOME}

### Install solr
RUN mkdir -p /data/db \
  && cd /opt \
  && wget http://archive.apache.org/dist/lucene/solr/${SOLR_VERSION}/solr-${SOLR_VERSION}.tgz \
  && tar xzf solr-${SOLR_VERSION}.tgz


RUN mkdir ${OLS_HOME}/ontologies
#ADD ontologies/*.owl ${OLS_HOME}/ontologies/
RUN ls -l ${OLS_HOME}/ontologies/

## Prepare configuration files
#ADD ols-web/src/main/resources/application.properties ${OLS_HOME}
## Start MongoDB and
### Load configuration into MongoDB
RUN mongod --smallfiles --fork --logpath /var/log/mongodb.log \
    && cd ${OLS_HOME} \
    && java -jar ${OLS_HOME}/ols-config-importer.jar \
    && sleep 10

## Start MongoDB and SOLR Build/update the indexes
RUN mongod --smallfiles --fork --logpath /var/log/mongodb.log \
  && /opt/solr-${SOLR_VERSION}/bin/solr -Dsolr.solr.home=${OLS_HOME}/solr-5-config/ -Dsolr.data.dir=${OLS_HOME} \
  && java ${JAVA_OPTS} -Dobo.db.xrefs=https://raw.githubusercontent.com/geneontology/go-site/a94d68f4e57264db2ff3692866a680c3fb9dda9d/metadata/db-xrefs.yaml -Dols.home=${OLS_HOME} -jar ${OLS_HOME}/ols-indexer.jar

## Expose the tomcat port
EXPOSE 8080

CMD cd ${OLS_HOME} \
    && mongod --smallfiles --fork --logpath /var/log/mongodb.log \
    && /opt/solr-${SOLR_VERSION}/bin/solr -Dsolr.solr.home=${OLS_HOME}/solr-5-config/ -Dsolr.data.dir=${OLS_HOME} \
    && java -jar -Dols.home=${OLS_HOME} ols-boot.war
