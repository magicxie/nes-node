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
    uglify: {
      options: {
        banner: '/*! <%= pkg.name %> <%= grunt.template.today("yyyy-mm-dd") %> */\n'
      },
      build: {
        src: 'src/2a03.js',
        dest: 'build/<%= pkg.name %>.min.js'
      }
    },
    coveralls: {
      options: {
        dryRun : true,
        coverageDir: 'src',
        force: true,
        recursive: true
      }
    }
  }

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.registerTask 'compile', ['coffee']

  grunt.loadNpmTasks 'grunt-coveralls';

 # Load the plugin that provides the "uglify" task.
  grunt.loadNpmTasks 'grunt-contrib-uglify';
  # Default task(s).
  grunt.registerTask 'default', ['compile','coveralls','uglify'];