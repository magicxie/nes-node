module.exports = (grunt) ->
  grunt.initConfig {
    pkg: grunt.file.readJSON('package.json'),
    coffee:
      src_to_js:
        options:
          bare: true
          sourceMap: true
        expand: true
        flatten: false
        cwd: "src"
        src: ["**/*.coffee"]
        dest: 'src'
        ext: ".js"
      test_to_js:
        options:
          bare: true
          sourceMap: true
        expand: true
        flatten: false
        cwd: "test"
        src: ["**/*.coffee"]
        dest: 'test'
        ext: ".js"
    uglify:
      options:
        banner: '/*! <%= pkg.name %> <%= grunt.template.today("yyyy-mm-dd") %> */\n'

      build:
        src: 'src/2a03.js',
        dest: 'build/<%= pkg.name %>.min.js'

    blanket:
      instrument:
        options:
          debug: true
        files:
          'coverage/src': ['src/'],
          'coverage/test': ['test/']
    mochaTest:
      test:
        options:
          timeout: 10000
          reporter: 'spec'
        src: ['coverage/test/*.js']
      coverage:
        options:
          reporter: 'mocha-lcov-reporter'
          quiet: true
          captureFile: 'coverage/lcov.info'
        src: ['coverage/src/*.js']
    coveralls:
      options:
        src: 'coverage/lcov.info'
      default :
        src: 'coverage/lcov.info'
  }

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-mocha-test'
  grunt.loadNpmTasks 'grunt-blanket'
  grunt.loadNpmTasks 'grunt-coveralls'
  # Load the plugin that provides the "uglify" task.
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  # Default task(s).
  grunt.registerTask 'compile', ['coffee']
  grunt.registerTask 'test', ['blanket', 'mochaTest']

  grunt.registerTask 'default', ['compile', 'test', 'uglify']