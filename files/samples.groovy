1.upto(7) { i->
  workflowJob("chapter-${i}") {
    displayName "Chapter ${i}"
    
    triggers {
      scm('@daily')
    }
    definition {
      cpsScm {
        scm {
          git 'https://github.com/dockerhp/code-samples.git'
        }
        scriptPath "Chapter ${i}/Jenkinsfile"
      }
    }
  }
}

