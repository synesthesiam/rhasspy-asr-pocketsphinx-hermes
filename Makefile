SHELL := bash

.PHONY: check venv dist sdist pyinstaller debian docker

version := $(shell cat VERSION)
architecture := $(shell dpkg-architecture | grep DEB_BUILD_ARCH= | sed 's/[^=]\+=//')

debian_package := rhasspy-asr-pocketsphinx-hermes_$(version)_$(architecture)
debian_dir := debian/$(debian_package)

check:
	flake8 rhasspyasr_pocketsphinx_hermes/*.py
	pylint rhasspyasr_pocketsphinx_hermes/*.py
	mypy rhasspyasr_pocketsphinx_hermes/*.py

venv:
	rm -rf .venv/
	python3 -m venv .venv
	.venv/bin/pip3 install wheel setuptools
	.venv/bin/pip3 install -r requirements_all.txt

dist: sdist debian

test:
	scripts/test_wavs.sh

sdist:
	python3 setup.py sdist

pyinstaller:
	mkdir -p dist
	pyinstaller -y --workpath pyinstaller/build --distpath pyinstaller/dist rhasspyasr_pocketsphinx_hermes.spec
	tar -C pyinstaller/dist -czf dist/rhasspy-asr-pocketsphinx-hermes_$(version)_$(architecture).tar.gz rhasspyasr_pocketsphinx_hermes/

debian: pyinstaller
	mkdir -p dist
	rm -rf "$(debian_dir)"
	mkdir -p "$(debian_dir)/DEBIAN" "$(debian_dir)/usr/bin" "$(debian_dir)/usr/lib"
	cat debian/DEBIAN/control | version=$(version) architecture=$(architecture) envsubst > "$(debian_dir)/DEBIAN/control"
	cp debian/bin/* "$(debian_dir)/usr/bin/"
	cp -R pyinstaller/dist/rhasspyasr_pocketsphinx_hermes "$(debian_dir)/usr/lib/"
	cd debian/ && fakeroot dpkg --build "$(debian_package)"
	mv "debian/$(debian_package).deb" dist/

docker: pyinstaller
	docker build . -t "rhasspy/rhasspy-asr-pocketsphinx-hermes:$(version)"

deploy:
	echo "$$DOCKER_PASSWORD" | docker login -u "$$DOCKER_USERNAME" --password-stdin
	docker push rhasspy/rhasspy-asr-pocketsphinx:$(version)
