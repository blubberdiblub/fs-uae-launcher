#!/usr/bin/env python3
import os
import config as project

f = open("setup.py", "w", newline="\n")
f.write("""\
import os
import sys
if sys.argv[1] == "build_exe":
    from cx_Freeze import setup, Executable
else:
    from distutils.core import setup


""")

with open("config.py", "r") as pf:
    f.write(pf.read())

f.write("""

# add unique parent directories to sys.path
for p in set(package_map.values()):
    sys.path.insert(0, p)

setup_packages = set()
package_dir = {}
package_data = {}
setup_options = {}
setup_cmdclass = {}


res_dirs = []
""")

for name in sorted(project.packages):
    f.write("res_dirs.append({0})\n".format(repr(name + "/res")))

f.write("""

def add_package(package_name, package_dir_name):
    setup_packages.add(package_name)
    local_name = package_name.replace(".", "/")
    if os.path.exists(local_name):
        package_dir_path = local_name
    else:
        package_dir_path = package_dir_name + "/" + local_name
    package_dir[package_name] = package_dir_path
    package_data[package_name] = []
    for dir_path, dir_names, file_names in os.walk(package_dir_path):
        for name in file_names:
            n, ext = os.path.splitext(name)
            if ext in [".py", ".pyc", ".pyo", ".swp", "*.swo"]:
                continue
            path = os.path.join(dir_path[len(package_dir_path) + 1:], name)
            package_data[package_name].append(path)
            setup_packages.add(package_name)


def add_packages():
    for name in sorted(packages):
        dir_name = package_map[name]
        add_package(name, dir_name)
        for dir_path, dir_names, file_names in os.walk(
                package_dir[name]):
            for n in file_names:
                if n != "__init__.py":
                    continue
                pname_rev = []
                path = dir_path
                while os.path.exists(os.path.join(path, "__init__.py")):
                    pname_rev.append(os.path.basename(path))
                    path = os.path.dirname(path)
                sub_name = ".".join(reversed(pname_rev))
                package_dir[sub_name] = (package_dir[name] + "/" +
                                         sub_name.replace(".", "/"))
                add_package(sub_name, dir_name)


add_packages()

setup_kwargs = {
    "name": py_name,
    "version": version,
    "author": author,
    "author_email": author_email,
    "packages": setup_packages,
    "package_dir": package_dir,
    "package_data": package_data,
    "options": setup_options,
    "cmdclass": setup_cmdclass,
}

if sys.argv[1] == "build_exe":
    if sys.platform == "win32":
        setup_kwargs["executables"] = [
            Executable(s, base="Win32GUI", icon="icon/" + s + ".ico") 
                for s in scripts]
    else:
        setup_kwargs["executables"] = [Executable(s) for s in scripts]

    setup_kwargs["version"] = "9.8.7"
    build_exe_options = {
        "includes": [
        #    "ctypes",
        #    "logging",
        ],
        "excludes": [
            "tkconstants",
            "tkinter",
            "tk",
            "tcl",
        ],
        "include_files": [],
        "zip_includes": [],
    }
    #for res_dir in res_dirs:
    #    print(res_dir)
    #    build_exe_options["zip_includes"].append((res_dir, res_dir))

    for name in sorted(package_map.keys()):
        sp = os.path.join(name, "res")
        if not os.path.exists(sp):
            # setup with alternative source dir
            sp = os.path.join(package_map[name], name, "res")
        if not os.path.exists(sp):
            continue
        dp = os.path.join(name, "res")
        # dp = os.path.join("share", tar_name, dp)
        #build_exe_options["include_files"].append((sp, dp))
        for dir_path, dir_names, file_names in os.walk(sp):
            for name in file_names:
                p = os.path.join(dir_path, name)
                rp = p[len(sp) + 1:]
                #build_exe_options["zip_includes"].append((p, os.path.join(dp, rp)))
                build_exe_options["include_files"].append((p, os.path.join(dp, rp)))
                #print(p, rp)
    setup_options["build_exe"] = build_exe_options
    if os.path.exists("extra_imports.py"):
        build_exe_options["includes"].append("extra_imports")

    build_exe_options["packages"] = setup_packages


if sys.platform == "win32" and False:
    setup_kwargs["windows"] = scripts

if sys.platform == "darwin":
    setup_kwargs["name"] = title
    setup_kwargs["version"] = "9.8.7"
else:
    setup_kwargs["scripts"] = scripts

setup(**setup_kwargs)
""")

f.close()

f = open("Makefile", "w", newline="\n")


def write(data):
    f.write(data.replace("    ", "\t"))


write("""\
version := $(strip $(shell cat VERSION))
series := $(strip $(shell cat SERIES))
prefix := /usr
build_dir := "."
dist_name = {tar_name}-$(version)
dist_dir := $(build_dir)/$(dist_name)

""".format(tar_name=project.tar_name))


for name, dir_name in sorted(project.package_map.items()):
    write("""\
ifeq ($(wildcard {0}),)
    {0}_dir := "{1}"
else
    {0}_dir := "."
endif

""".format(name, dir_name))


locales = []
for name in os.listdir("po"):
    if name.endswith(".po"):
        locale, ext = os.path.splitext(name)
        locales.append(locale)
locales.sort()


write("""\
all: mo

share/locale/%/LC_MESSAGES/{0}.mo: po/%.po
    mkdir -p share/locale/$*/LC_MESSAGES
    msgfmt --verbose $< -o $@

catalogs = \\
{1}

mo: $(catalogs)

""".format(project.tar_name, " \\\n".join(
           ["    share/locale/{0}/LC_MESSAGES/{1}.mo".format(x,
           project.tar_name) for x in locales])))


write("""\
install: mo
    mkdir -p $(DESTDIR)$(prefix)/share
    cp -a share/* $(DESTDIR)$(prefix)/share

    mkdir -p $(DESTDIR)$(prefix)/share/doc/{project}
    cp -a README COPYING $(DESTDIR)$(prefix)/share/doc/{project}

dist_dir := {project}-$(version)

""".format(project=project.tar_name))


write("""\
distdir:
    rm -Rf $(dist_dir)/*
    mkdir -p $(dist_dir)

""")


for name, dir_name in sorted(project.package_map.items()):
    write("""\
    cp -a $({0}_dir)/{0} $(dist_dir)/
""".format(name))


copy_files = [
    "README",
    "COPYING",
    "INSTALL",
    "VERSION",
    "SERIES",
    "Makefile",
    "setup.py",
    "update-version",
    "debian/changelog",
    "debian/compat",
    "debian/control",
    "debian/copyright",
    "debian/rules",
    "debian/source/format",
    "debian/links",
    "po-update.py",
    "extra_imports.py",
    "icon/{0}.ico".format(project.tar_name),
    "icon/{0}.icns".format(project.tar_name),
    "{0}.spec".format(project.tar_name),
    "{0}".format(project.tar_name),
    "dist/linux/build.py",
    "dist/linux/Makefile",
    "dist/linux/standalone.py",
    "dist/steamos/Makefile",
    "dist/windows/iscc.py",
    "dist/windows/Makefile",
    "dist/windows/sign.py",
    "dist/windows/{0}.iss".format(project.tar_name),
    "macosx/Makefile",
    "macosx/fs-make-standalone-app.py",
    "macosx/Info.plist",
]
for locale in locales:
    copy_files.append("po/{0}.po".format(locale))
copy_files.sort()


write("""\
    cp -a share $(dist_dir)/
    mkdir $(dist_dir)/po/

    find $(dist_dir) -name "*.mo" -delete
    find $(dist_dir) -name "*.pyc" -delete
    find $(dist_dir) -name "*.pyo" -delete
    find $(dist_dir) -name __pycache__ -delete

""")


created_dirs = set()

for copy_file in copy_files:
    if not os.path.exists(copy_file):
        continue
    if "/" in copy_file:
        if not os.path.dirname(copy_file) in created_dirs:
            write("    mkdir -p $(dist_dir)/{0}\n".format(
                os.path.dirname(copy_file)))
            created_dirs.add(os.path.dirname(copy_file))
    write("    cp {0} $(dist_dir)/{1}\n".format(
        copy_file, os.path.dirname(copy_file)))


write("""\
    cd $(dist_dir) && ./update-version setup.py --strict
    cd $(dist_dir) && ./update-version debian/changelog
    cd $(dist_dir) && ./update-version macosx/Info.plist --strict
    cd $(dist_dir) && ./update-version {project} --update-series
    cd $(dist_dir) && ./update-version {project}.spec

""".format(project=project.tar_name))

write("""\
dist: distdir
    find $(dist_dir) -exec touch \{\} \;
    cd "$(build_dir)" && tar zcfv $(dist_name).tar.gz $(dist_name)

""")


write("""\
windows-dist: distdir
    cd $(dist_dir)/dist/windows && make
    mv $(dist_dir)/{project}_*windows* .
    rm -Rf $(dist_dir)

macosx-dist: distdir
    cd $(dist_dir)/macosx && make
    mv $(dist_dir)/{project}_*macosx* .
    rm -Rf $(dist_dir)

clean-dist:
    rm -Rf {project}-* {project}_*
    rm -Rf debian/{project}*

clean:
    #rm -Rf build
    find share -name "*.mo" -delete
    find . -name "*.pyc" -delete

distclean: clean clean-dist
""".format(project=project.tar_name))
