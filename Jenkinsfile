def label = "ewallet-${UUID.randomUUID().toString()}"
def yamlSpec = """
spec:
  nodeSelector:
    cloud.google.com/gke-preemptible: "true"
  tolerations:
    - key: dedicated
      operator: Equal
      value: worker
      effect: NoSchedule
"""

podTemplate(
    label: label,
    yaml: yamlSpec,
    containers: [
        containerTemplate(
            name: 'jnlp',
            image: 'jenkins/jnlp-slave:3.19-1-alpine',
            args: '${computer.jnlpmac} ${computer.name}',
            resourceRequestCpu: '500m',
            resourceLimitCpu: '1000m',
            resourceRequestMemory: '512Mi',
            resourceLimitMemory: '1024Mi',
        ),
        containerTemplate(
            name: 'postgresql',
            image: 'postgres:9.6.9-alpine',
            resourceRequestCpu: '300m',
            resourceLimitCpu: '800m',
            resourceRequestMemory: '512Mi',
            resourceLimitMemory: '1024Mi',
            ports: [
                portMapping(
                    name: 'postgresql',
                    containerPort: 5432,
                    hostPort: 5432
                )
            ]
        ),
    ],
    volumes: [
        hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock'),
        hostPathVolume(mountPath: '/usr/bin/docker', hostPath: '/usr/bin/docker'),
    ],
) {
    node(label) {
        Random random = new Random()
        def tmpDir = pwd(tmp: true)

        def project = 'gcr.io/omise-go'
        def appName = 'ewallet'
        def imageName = "${project}/${appName}"
        def releaseVersion = '0.1.0-beta'

        def nodeIP = getNodeIP()
        def gitCommit

        stage('Pull') {
            checkout scm
            gitCommit = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        }

        stage('Test') {
            withDockerContainer(
                image: 'elixir:1.6.5-alpine',
                args: [
                    "-v .:/build:ro",
                    "-e MIX_ENV=test",
                    "-e DATABASE_URL=postgresql://postgres@${nodeIP}:5432/ewallet_${gitCommit}_ewallet",
                    "-e LOCAL_LEDGER_DATABASE_URL=postgresql://postgres@${nodeIP}:5432/ewallet_${gitCommit}_local_ledger",
                ].join(' ')
            ) {
                sh('mix local.hex --force')
                sh('mix local.rebar --force')
                sh('mix do format --check-formatted, credo')
                sh('mix do ecto.create, ecto.migrate')
                sh('mix test')
            }
        }
    }
}

String getNodeIP() {
    def rawNodeIP = sh(script: 'ip -4 -o addr show scope global', returnStdout: true).trim()
    def matched = (rawNodeIP =~ /inet (\d+\.\d+\.\d+\.\d+)/)
    return "" + matched[0].getAt(1)
}

String getPodID(String opts) {
    def pods = sh(script: "kubectl get pods ${opts} -o name", returnStdout: true).trim()
    def matched = (pods.split()[0] =~ /pods\/(.+)/)
    return "" + matched[0].getAt(1)
}
