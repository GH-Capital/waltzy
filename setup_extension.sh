#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# ==========================================
# TachiGen Auto-Installer Scri
# Generated for: Lunaranime
# ==========================================

# 1. Configuration Variables
EXT_NAME="Lunaranime"
EXT_SLUG="lunaranime"
EXT_LANG="id"
CLASS_NAME="Lunaranime"
PKG_NAME="eu.kanade.tachiyomi.extension.id.lunaranime"

# 2. Define Paths (Monorepo Compatible)
# Target Module: src/<lang>/<slug> (e.g., src/en/mysource)
MODULE_PATH="src/$EXT_LANG/$EXT_SLUG"
# Gradle file location
GRADLE_FILE="$MODULE_PATH/build.gradle"
# Source file location (matches package structure)
# e.g., src/en/mysource/src/eu/kanade/tachiyomi/extension/en/mysource
SRC_PATH="$MODULE_PATH/src/eu/kanade/tachiyomi/extension/id/lunaranime"
KOTLIN_FILE="$SRC_PATH/$CLASS_NAME.kt"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==> TachiGen Automation Started${NC}"
echo -e "${BLUE}    Extension: $EXT_NAME ($EXT_LANG)${NC}"
echo -e "${BLUE}    Module: $MODULE_PATH${NC}"

# 3. Create Directory Structure
if [ ! -d "$SRC_PATH" ]; then
    echo -e "${GREEN}[+] Creating directory structure: $SRC_PATH${NC}"
    mkdir -p "$SRC_PATH"
else
    echo -e "${BLUE}    -> Directories already exist.${NC}"
fi

# 4. Write build.gradle
# Logic: Backup if exists, then write new.
if [ -f "$GRADLE_FILE" ]; then
    echo -e "${BLUE}    [i] build.gradle exists. Backing up to .bak${NC}"
    cp "$GRADLE_FILE" "$GRADLE_FILE.bak"
fi

echo -e "${GREEN}[+] Writing Configuration: build.gradle${NC}"
cat <<'EOF_TACHIGEN_AUTO_GEN' > "$GRADLE_FILE"
apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply plugin: 'kotlinx-serialization'

ext {
    extName = 'Lunaranime'
    pkgNameSuffix = 'id.lunaranime'
    extClass = '.Lunaranime'
    extVersionCode = 1
    isNsfw = false
}

apply from: "$rootDir/common.gradle"
EOF_TACHIGEN_AUTO_GEN

# 5. Write Kotlin Source File
if [ -f "$KOTLIN_FILE" ]; then
    echo -e "${BLUE}    [i] Kotlin file exists. Backing up to .bak${NC}"
    cp "$KOTLIN_FILE" "$KOTLIN_FILE.bak"
fi

echo -e "${GREEN}[+] Writing Source Code: $CLASS_NAME.kt${NC}"
cat <<'EOF_TACHIGEN_AUTO_GEN' > "$KOTLIN_FILE"
package eu.kanade.tachiyomi.extension.id.lunaranime

import eu.kanade.tachiyomi.network.GET
import eu.kanade.tachiyomi.network.interceptor.rateLimit
import eu.kanade.tachiyomi.source.model.FilterList
import eu.kanade.tachiyomi.source.model.MangasPage
import eu.kanade.tachiyomi.source.model.Page
import eu.kanade.tachiyomi.source.model.SChapter
import eu.kanade.tachiyomi.source.model.SManga
import eu.kanade.tachiyomi.source.online.HttpSource
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.Headers
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import uy.kohesive.injekt.injectLazy
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

class Lunaranime : HttpSource() {

    override val name = "Lunaranime"

    override val baseUrl = "https://lunaranime.ru"

    private val apiBaseUrl = "https://api.lunaranime.ru"

    override val lang = "id"

    override val supportsLatest = true

    private val json: Json by injectLazy()

    override val client: OkHttpClient = network.cloudflareClient.newBuilder()
        .rateLimit(2)
        .build()

    override fun headersBuilder(): Headers.Builder = super.headersBuilder()
        .add("Referer", "$baseUrl/")
        .add("Origin", baseUrl)

    // ============================== Popular ==============================

    override fun popularMangaRequest(page: Int): Request {
        val url = "$apiBaseUrl/api/manga?page=$page&limit=20&sort=popular"
        return GET(url, headers)
    }

    override fun popularMangaParse(response: Response): MangasPage {
        val responseBody = response.body.string()
        val result = json.decodeFromString<MangaListResponse>(responseBody)
        val mangas = result.data.map { it.toSManga(apiBaseUrl) }
        val hasNextPage = result.data.size >= 20
        return MangasPage(mangas, hasNextPage)
    }

    // ============================== Latest ==============================

    override fun latestUpdatesRequest(page: Int): Request {
        val url = "$apiBaseUrl/api/manga?page=$page&limit=20&sort=latest"
        return GET(url, headers)
    }

    override fun latestUpdatesParse(response: Response): MangasPage = popularMangaParse(response)

    // ============================== Search ==============================

    override fun searchMangaRequest(page: Int, query: String, filters: FilterList): Request {
        val url = "$apiBaseUrl/api/manga".toHttpUrl().newBuilder()
            .addQueryParameter("page", page.toString())
            .addQueryParameter("limit", "20")
            .addQueryParameter("q", query)
            .build()
            .toString()
        return GET(url, headers)
    }

    override fun searchMangaParse(response: Response): MangasPage = popularMangaParse(response)

    // ============================== Details ==============================

    override fun mangaDetailsRequest(manga: SManga): Request {
        val slug = manga.url.trimStart('/').substringAfterLast("/")
        return GET("$apiBaseUrl/api/manga/$slug", headers)
    }

    override fun mangaDetailsParse(response: Response): SManga {
        val responseBody = response.body.string()
        val result = json.decodeFromString<MangaDetailResponse>(responseBody)
        val data = result.data
        return SManga.create().apply {
            title = data.title
            url = "/manga/${data.slug}"
            thumbnail_url = data.cover?.let { if (it.startsWith("http")) it else "$apiBaseUrl$it" }
                ?: data.thumbnail?.let { if (it.startsWith("http")) it else "$apiBaseUrl$it" }
            author = data.author
            artist = data.artist
            description = data.description
            genre = data.genres?.joinToString(", ")
            status = when (data.status?.lowercase(Locale.US)) {
                "ongoing" -> SManga.ONGOING
                "completed" -> SManga.COMPLETED
                "hiatus" -> SManga.ON_HIATUS
                "cancelled", "canceled" -> SManga.CANCELLED
                else -> SManga.UNKNOWN
            }
        }
    }

    // ============================== Chapters ==============================

    override fun chapterListRequest(manga: SManga): Request {
        val slug = manga.url.trimStart('/').substringAfterLast("/")
        return GET("$apiBaseUrl/api/manga/$slug/chapters", headers)
    }

    override fun chapterListParse(response: Response): List<SChapter> {
        val responseBody = response.body.string()
        val result = json.decodeFromString<ChapterListResponse>(responseBody)
        return result.data.map { ch ->
            SChapter.create().apply {
                name = ch.title ?: "Chapter ${ch.number ?: "?"}"
                url = ch.url
                chapter_number = ch.number ?: -1f
                date_upload = ch.date?.let { parseDate(it) } ?: 0L
            }
        }.reversed()
    }

    // ============================== Pages ==============================

    override fun pageListRequest(chapter: SChapter): Request {
        val trimmedUrl = chapter.url.trimStart('/')
        val parts = trimmedUrl.split("/")
        // Expected format: manga/{slug}/{chapterId} or similar
        val slug = if (parts.size >= 2) parts[1] else ""
        val chapterId = if (parts.size >= 3) parts[2] else ""
        require(slug.isNotEmpty() && chapterId.isNotEmpty()) {
            "Invalid chapter URL format: ${chapter.url}"
        }
        return GET("$apiBaseUrl/api/manga/$slug/chapters/$chapterId", headers)
    }

    override fun pageListParse(response: Response): List<Page> {
        val responseBody = response.body.string()
        val result = json.decodeFromString<PageListResponse>(responseBody)
        return result.data.mapIndexed { index, pageData ->
            val imageUrl = if (pageData.url.startsWith("http")) pageData.url else "$apiBaseUrl${pageData.url}"
            Page(index, imageUrl = imageUrl)
        }
    }

    override fun imageUrlParse(response: Response): String {
        throw UnsupportedOperationException("Not used.")
    }

    // ============================== Utilities ==============================

    private val dateFormats: List<SimpleDateFormat> by lazy {
        listOf(
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US),
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US),
            SimpleDateFormat("yyyy-MM-dd", Locale.US),
        ).also { formats ->
            val utc = TimeZone.getTimeZone("UTC")
            formats.forEach { it.timeZone = utc }
        }
    }

    private fun parseDate(dateStr: String): Long {
        for (format in dateFormats) {
            try {
                return format.parse(dateStr)?.time ?: continue
            } catch (_: Exception) {
                // Try next format
            }
        }
        return 0L
    }

    // ============================== Data Classes ==============================

    @Serializable
    data class MangaListResponse(
        val data: List<MangaData> = emptyList(),
    )

    @Serializable
    data class MangaDetailResponse(
        val data: MangaData,
    )

    @Serializable
    data class MangaData(
        val title: String,
        val slug: String,
        val cover: String? = null,
        val thumbnail: String? = null,
        val author: String? = null,
        val artist: String? = null,
        val description: String? = null,
        val status: String? = null,
        val genres: List<String>? = null,
    ) {
        fun toSManga(apiBaseUrl: String): SManga = SManga.create().apply {
            title = this@MangaData.title
            url = "/manga/${this@MangaData.slug}"
            val img = this@MangaData.cover ?: this@MangaData.thumbnail
            thumbnail_url = img?.let { if (it.startsWith("http")) it else "$apiBaseUrl$it" }
        }
    }

    @Serializable
    data class ChapterListResponse(
        val data: List<ChapterData> = emptyList(),
    )

    @Serializable
    data class ChapterData(
        val title: String? = null,
        val number: Float? = null,
        val url: String,
        val date: String? = null,
        val id: String? = null,
    )

    @Serializable
    data class PageListResponse(
        val data: List<PageData> = emptyList(),
    )

    @Serializable
    data class PageData(
        val url: String,
    )
}
EOF_TACHIGEN_AUTO_GEN

# 6. Git Operations
echo -e "${GREEN}[+] Checking Git Status...${NC}"
if [ ! -d ".git" ]; then
    echo -e "${BLUE}    -> Initializing new Git repository...${NC}"
    git init
    git branch -M main
fi

# Configure Git User (Essential for GitHub Actions)
if [ -n "$GITHUB_TOKEN" ]; then
    echo -e "${BLUE}    -> Configuring Git User for CI...${NC}"
    git config --global user.email "actions@github.com"
    git config --global user.name "GitHub Actions"
fi

git add .

# Only commit if there are changes
if ! git diff-index --quiet HEAD --; then
    git commit -m "TachiGen: Update/Install $EXT_NAME"
    echo -e "${GREEN}[+] Changes committed to git.${NC}"
else
    echo -e "${BLUE}[i] No changes detected to commit.${NC}"
fi


# No GitHub Token provided in TachiGen. Skipping Auto-Push.
echo -e "${BLUE}[i] GitHub Token not found. Files are committed locally.${NC}"
echo -e "${BLUE}[i] To push manually: git remote add origin <URL> && git push -u origin main${NC}"


echo -e "
${GREEN}✅ SETUP COMPLETE!${NC}"
echo -e "To build the APK, run the following command:"
echo -e "${BLUE}./gradlew :src:$EXT_LANG:$EXT_SLUG:assembleDebug${NC}"
