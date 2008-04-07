#!/usr/bin/env python
from distutils.core import setup
setup(name="py-ApeTag",
      version="1.2",
      description="A pure Python library for manipulating APEv2 and ID3v1 tags",
      author="Jeremy Evans",
      author_email="code@jeremyevans.net",
      url="http://sourceforge.net/projects/pylibape/",
      classifiers= ['Development Status :: 5 - Production/Stable',
                    'Environment :: Other Environment',
                    'Intended Audience :: Developers',
                    'License :: OSI Approved :: MIT License',
                    'Natural Language :: English',
                    'Operating System :: OS Independent',
                    'Programming Language :: Python',
                    'Topic :: Multimedia'],
      py_modules=["ApeTag"],
)


