import com.android.build.api.instrumentation.AsmClassVisitorFactory
import com.android.build.api.instrumentation.ClassContext
import com.android.build.api.instrumentation.ClassData
import com.android.build.api.instrumentation.FramesComputationMode
import com.android.build.api.instrumentation.InstrumentationParameters
import com.android.build.api.instrumentation.InstrumentationScope
import java.util.Properties
import org.objectweb.asm.ClassVisitor
import org.objectweb.asm.Label
import org.objectweb.asm.MethodVisitor
import org.objectweb.asm.Opcodes

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePropertiesFile = rootProject.file("key.properties")
val releaseKeystoreProperties = Properties()
val hasReleaseSigningConfig = releaseKeystorePropertiesFile.exists()
if (hasReleaseSigningConfig) {
    releaseKeystorePropertiesFile.inputStream().use { releaseKeystoreProperties.load(it) }
}

fun releaseSigningProperty(name: String): String {
    return releaseKeystoreProperties.getProperty(name)
        ?: throw GradleException("Missing Android signing property: $name")
}

android {
    namespace = "com.slovofon.app"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.slovofon.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testApplicationId = "com.slovofon.app.debug.test"
        testInstrumentationRunner = "com.slovofon.app.SlovofonLifecycleInstrumentation"
    }

    testBuildType = "debug"

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                storeFile = file(releaseSigningProperty("storeFile"))
                storePassword = releaseSigningProperty("storePassword")
                keyAlias = releaseSigningProperty("keyAlias")
                keyPassword = releaseSigningProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            if (hasReleaseSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val requiresReleaseSigning = allTasks.any { task ->
        task.project == project &&
            task.name.contains("Release", ignoreCase = true) &&
            (task.name.contains("assemble", ignoreCase = true) ||
                task.name.contains("bundle", ignoreCase = true) ||
                task.name.contains("package", ignoreCase = true))
    }
    if (requiresReleaseSigning && !hasReleaseSigningConfig) {
        throw GradleException(
            "Android release signing is not configured. Copy android/key.properties.example " +
                "to android/key.properties and fill the local keystore path/passwords.",
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// AndroidX issue 3214: some Android 11 builds deliver a controller with an
// empty framework package. Media3 throws before our session callback runs.
// Normalize only that invalid identity in the legacy shim, keeping it
// unprivileged. Remove this visitor when the pinned Media3 fix is upstream.
abstract class GuardMedia3LegacyController :
    AsmClassVisitorFactory<InstrumentationParameters.None> {
    override fun isInstrumentable(classData: ClassData): Boolean =
        classData.className == "androidx.media3.session.legacy.MediaSessionManager\$RemoteUserInfo"

    override fun createClassVisitor(
        classContext: ClassContext,
        nextClassVisitor: ClassVisitor,
    ): ClassVisitor {
        val api = instrumentationContext.apiVersion.get()
        val framework = "android/media/session/MediaSessionManager\$RemoteUserInfo"
        return object : ClassVisitor(api, nextClassVisitor) {
            private var matched = false

            override fun visitMethod(
                access: Int,
                name: String,
                descriptor: String,
                signature: String?,
                exceptions: Array<out String>?,
            ): MethodVisitor {
                val method = super.visitMethod(access, name, descriptor, signature, exceptions)
                if (name != "<init>" || descriptor != "(L$framework;)V") return method
                matched = true
                return object : MethodVisitor(api, method) {
                    override fun visitCode() {
                        super.visitCode()
                        val unknown = Label()
                        val done = Label()
                        visitVarInsn(Opcodes.ALOAD, 1)
                        visitJumpInsn(Opcodes.IFNULL, unknown)
                        visitVarInsn(Opcodes.ALOAD, 1)
                        visitMethodInsn(
                            Opcodes.INVOKEVIRTUAL, framework, "getPackageName",
                            "()Ljava/lang/String;", false,
                        )
                        visitMethodInsn(
                            Opcodes.INVOKESTATIC, "android/text/TextUtils", "isEmpty",
                            "(Ljava/lang/CharSequence;)Z", false,
                        )
                        visitJumpInsn(Opcodes.IFEQ, done)
                        visitLabel(unknown)
                        visitTypeInsn(Opcodes.NEW, framework)
                        visitInsn(Opcodes.DUP)
                        visitLdcInsn("com.slovofon.unidentified_media_controller")
                        visitInsn(Opcodes.ICONST_M1)
                        visitInsn(Opcodes.ICONST_M1)
                        visitMethodInsn(
                            Opcodes.INVOKESPECIAL, framework, "<init>",
                            "(Ljava/lang/String;II)V", false,
                        )
                        visitVarInsn(Opcodes.ASTORE, 1)
                        visitLabel(done)
                    }
                }
            }

            override fun visitEnd() {
                check(matched) { "Review the Media3 legacy controller workaround." }
                super.visitEnd()
            }
        }
    }
}

androidComponents.onVariants { variant ->
    variant.instrumentation.transformClassesWith(
        GuardMedia3LegacyController::class.java,
        InstrumentationScope.ALL,
    ) { }
    variant.instrumentation.setAsmFramesComputationMode(
        FramesComputationMode.COMPUTE_FRAMES_FOR_INSTRUMENTED_METHODS,
    )
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.media3:media3-session") {
        version { strictly("1.10.1") }
    }
}
