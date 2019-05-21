project('vala-starter', ['vala', 'c'])

deps = [
  dependency('gtk+-3.0'),
  dependency('sqlite3',required: false),
  dependency('glib-2.0')
]

subdir('src')
subdir('ui')

install_data (
    'src/com.github.maxx730.gclipboard.gschema.xml',
    install_dir: join_paths ('/usr/share/', 'glib-2.0', 'schemas'),
    rename: 'com.github.maxx730.gclipboard.gschema.xml'
)

executable('Clipboard',
           [src, resources],
           dependencies: deps,
           vala_args: [resource_args],
           install: true)
