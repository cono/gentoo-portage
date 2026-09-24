# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..14} )

inherit bash-completion-r1 optfeature python-single-r1

DESCRIPTION="Google Cloud CLI: gcloud, gsutil and bq command-line tools"
HOMEPAGE="https://cloud.google.com/sdk/"
SRC_URI="
	amd64? ( https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/${P}-linux-x86_64.tar.gz )
	arm64? ( https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/${P}-linux-arm.tar.gz )
"
S="${WORKDIR}/google-cloud-sdk"

# Apache-2.0 for the CLI itself, the rest is vendored lib/third_party
LICENSE="Apache-2.0 BSD BSD-2 MIT PSF-2 MPL-2.0 ISC"
SLOT="0"
KEYWORDS="-* amd64 ~arm64"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"
RESTRICT="mirror"

RDEPEND="${PYTHON_DEPS}"

QA_PREBUILT="opt/google-cloud-sdk/bin/gcloud-crc32c"

src_prepare() {
	default

	# Use the system Python instead of the bundled interpreter (only the
	# x86_64 tarball ships one).
	rm -rf platform/bundledpythonunix .install/bundled-python3-unix* || die

	# Updates and components come from Portage, not from the built-in
	# component manager (which would try to write to /opt as the user).
	sed -i -e 's/"disable_updater": false/"disable_updater": true/' \
		lib/googlecloudsdk/core/config.json || die
	grep -q '"disable_updater": true' lib/googlecloudsdk/core/config.json \
		|| die "failed to disable the component manager"

	# Installer, Windows and distro packaging bits, and the App Engine
	# dev servers whose runtimes are components we cannot install.
	rm -r install.sh install.bat deb rpm \
		bin/dev_appserver.py bin/java_dev_appserver.sh \
		bin/bootstrapping/install.py bin/bootstrapping/java_dev_appserver.py \
		|| die

	# gsutil's vendored macOS build of crcmod, with a Mach-O .so
	rm -r platform/gsutil/third_party/crcmod_osx || die

	# Every launcher picks its interpreter in setup_cloudsdk_python();
	# default CLOUDSDK_PYTHON to ours, but keep it overridable.
	local f
	for f in bin/{gcloud,gsutil,bq,docker-credential-gcloud,git-credential-gcloud.sh}; do
		sed -i -e "/^setup_cloudsdk_python() {\$/a\\
  CLOUDSDK_PYTHON=\"\${CLOUDSDK_PYTHON:-${PYTHON}}\"" "${f}" || die
		grep -qF "CLOUDSDK_PYTHON:-${PYTHON}" "${f}" \
			|| die "failed to set the Python interpreter in ${f}"
	done
}

src_install() {
	local dest=/opt/google-cloud-sdk

	insinto "${dest}"
	doins -r .install bin data lib platform properties VERSION
	fperms +x "${dest}"/bin/{gcloud,gcloud-crc32c,gsutil,bq,docker-credential-gcloud,git-credential-gcloud.sh}
	fperms +x "${dest}"/platform/{gsutil/gsutil,bq/bq.py}

	# The vendored libraries still carry Python 2 only files that are never
	# imported on Python 3; compileall skips them, but lists each one on
	# stdout.
	python_optimize "${ED}${dest}"/{bin/bootstrapping,lib,platform} >/dev/null

	local b
	for b in gcloud gsutil bq docker-credential-gcloud git-credential-gcloud.sh; do
		dosym -r "${dest}/bin/${b}" "/usr/bin/${b}"
	done

	newbashcomp completion.bash.inc gcloud
	bashcomp_alias gcloud gsutil bq

	dodoc README RELEASE_NOTES
}

pkg_postinst() {
	optfeature "kubectl for 'gcloud container clusters get-credentials'" sys-cluster/kubectl

	elog "The gcloud component manager is disabled; components (kubectl,"
	elog "gke-gcloud-auth-plugin, emulators, ...) cannot be installed with"
	elog "'gcloud components install'. Get them from the tree or upstream."
	elog
	elog "gcloud runs on ${EPYTHON} by default. Set CLOUDSDK_PYTHON to use a"
	elog "different interpreter."
}
