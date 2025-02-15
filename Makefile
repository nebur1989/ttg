APP_NAME    := travelgrunt
GITHUB_REPO := ivanilves/travelgrunt
API_VERSION := 0.2

APP_VERSION   := $(shell (git fetch --tags && git tag --sort=creatordate | grep -F "v${API_VERSION}." || echo UNDEFINED) | tail -n1)
CURRENT_PATCH := $(shell (git fetch --tags && git tag --sort=creatordate | grep -F "v${API_VERSION}." || echo -1) | tail -n1 | sed -r "s/^v([0-9]+\.){2}//")
NEXT_PATCH    := $(shell expr ${CURRENT_PATCH} + 1)
NEXT_VERSION  := v${API_VERSION}.${NEXT_PATCH}

BUILD_PATH   := ./cmd/${APP_NAME}
RELEASE_PATH := ./release

-include secrets.mk

default: dep build

all: dep build install

deploy: build install

dep:
	go mod tidy
	go mod vendor

build:
	cd ${BUILD_PATH} && go build

clean:
	git clean -fdx -e secrets.mk

install: PREFIX := /usr/local
install:
	install ${BUILD_PATH}/travelgrunt ${PREFIX}/bin/

changelog: LAST_RELEASED_TAG:=$(shell git tag --sort=creatordate | tail -n1)
changelog: GITHUB_COMMIT_URL:=https://github.com/${GITHUB_REPO}/commit
changelog:
	@echo "## Changelog" \
  && git log --oneline --reverse ${LAST_RELEASED_TAG}..HEAD | egrep -iv "^[0-9a-f]{7,} (Merge pull request |Merge branch |.*NORELEASE)" | \
	sed -r "s|^([0-9a-f]{7,}) (.*)|* [\`\1\`](${GITHUB_COMMIT_URL}/\1) \2|"

release-binary: GOOS    ?= $(shell uname -s | tr '[A-Z]' '[a-z]')
release-binary: GOARCH  ?= $(shell uname -m | sed 's/x86_64/amd64/')
release-binary: LDFLAGS := "-X 'main.appVersion=${NEXT_VERSION}'"
release-binary:
	mkdir -p ${RELEASE_PATH}/${APP_NAME}-${GOOS}-${GOARCH} && cd ${BUILD_PATH} && \
		GOOS=${GOOS} GOARCH=${GOARCH} go build -mod=vendor -ldflags ${LDFLAGS} -o ../../${RELEASE_PATH}/${APP_NAME}-${GOOS}-${GOARCH}/${APP_NAME}

release-binaries:
	${MAKE} --no-print-directory release-binary GOOS=linux  GOARCH=amd64
	${MAKE} --no-print-directory release-binary GOOS=darwin GOARCH=amd64
	${MAKE} --no-print-directory release-binary GOOS=darwin GOARCH=arm64

release-artifacts:
	cd ${RELEASE_PATH} && find . -mindepth 1 -maxdepth 1 -type d | xargs -i tar -C {} -zc ${APP_NAME} -f {}.tar.gz

release-metadata:
	echo ${NEXT_VERSION} >${RELEASE_PATH}/TAG
	echo ${NEXT_VERSION} >${RELEASE_PATH}/NAME
	${MAKE} --no-print-directory changelog >${RELEASE_PATH}/CHANGELOG.md
	cp -f README.md ${RELEASE_PATH}/

release: release-binaries release-artifacts release-metadata

next-version-tag:
	git tag ${NEXT_VERSION}

push-tags:
	git push --tags

github-release:
	scripts/github-create-release.sh ${GITHUB_REPO} ./release

github-assets:
	scripts/github-upload-assets.sh ${GITHUB_REPO} ./release

github: github-release github-assets

github-token:
	@test -n "${GITHUB_TOKEN}" || (echo "GITHUB_TOKEN not set!" >>/dev/stderr; exit 1)

full-release: github-token clean dep release next-version-tag push-tags github
