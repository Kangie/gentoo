# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit java-pkg-2 java-ant-2

MY_P="${PN}$(ver_rs 1- '')"

DESCRIPTION="InterProlog is a Java front-end and enhancement for Prolog"
HOMEPAGE="https://declarativa.com/InterProlog/"
SRC_URI="https://declarativa.com/InterProlog/${MY_P}.zip"

LICENSE="LGPL-2"
SLOT="0"
KEYWORDS="amd64"
IUSE="doc"

RDEPEND=">=virtual/jdk-1.8:*
	dev-java/junit:0"

DEPEND="${RDEPEND}
	app-arch/unzip
	>=dev-java/ant-1.10.14-r3:0
	|| (
		dev-lang/xsb
		dev-lang/swi-prolog
		dev-lang/yap )"

S="${WORKDIR}"/${MY_P}

EANT_GENTOO_CLASSPATH="junit"

src_prepare() {
	eapply "${FILESDIR}"/${P}-java1.4.patch
	eapply "${FILESDIR}"/${P}-java17.patch
	eapply_user

	cp "${FILESDIR}"/build.xml "${S}" || die
	mkdir "${S}"/src
	mv "${S}"/com "${S}"/src
	rm interprolog.jar junit.jar
}

src_compile() {
	java-pkg_jar-from junit
	eant jar $(use_doc)
}

src_install() {
	java-pkg_dojar dist/${PN}.jar

	if use doc ; then
		java-pkg_dohtml -r docs/*
		dodoc INSTALL.htm faq.htm prologAPI.htm
		dodoc -r images
		dodoc PaperEPIA01.doc
	fi
}
