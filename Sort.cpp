// Sort.cpp
// C++20 File Organizer: Symbol, Interactive, Multilanguage & Full Help Translation

#include <iostream>
#include <string>
#include <vector>
#include <algorithm>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <chrono>
#include <ctime>
#include <iomanip>
#include <cstdint>
#include <map>
#include <array>
#include <random> 
#include <cctype> 

using namespace std;
namespace fs = std::filesystem;
using namespace std::chrono;

// =========================================================================
// 1. GLOBALE TAAL DEFINITIES EN FUNCTIES
// =========================================================================

using TranslationMap = std::map<std::string, std::string>;
using LanguageMap = std::map<std::string, TranslationMap>;

/**
 * De uitgebreide map met vertalingen voor de hoofdoutput, logs en help-berichten.
 * Bevat nl, en, de, fr, jp, ar, ru, tr, zh (voorheen ch).
 */
LanguageMap g_translations = {
    {"nl", {
        // Hoofdberichten
        {"MSG_START_ACTION", "START met actie: "},
        {"MSG_PATH_NOT_FOUND", "⚠️ Pad niet gevonden: "},
        {"MSG_PROCESSING_DIR", "📂 Verwerken Map: "},
        {"MSG_FILE_FILTERED", "🚫 MIME GEFILTERD: "},
        {"MSG_COLLISION_TITLE", "💥 BESTANDSBOTSING DETECTEERD"},
        {"MSG_COLLISION_SRC", "➡️ Bron: "},
        {"MSG_COLLISION_DST", "🎯 Doel: "},
        {"MSG_COLLISION_EXISTS", " ❌ BESTAAT AL"},
        {"MSG_COLLISION_PROMPT", "❓ Actie: [A]nnuleren, [O]verslaan, Overslaan [A]lle, [V]ervangen, Vervangen [A]lle: "},
        {"MSG_OVERWRITE_OK", "🔄 Overschrijven gelukt."},
        {"MSG_SKIP_OK", "⏭️ Overgeslagen (bestaat)."},
        {"MSG_RENAME_OK", "#️⃣ Hernoemd om conflict te vermijden: "},
        {"MSG_CANCELED", "🚫 GEANNULEERD door gebruiker of geen bestanden verwerkt."},
        {"MSG_FINISHED", "✅ VOLTOOID: "},
        {"MSG_FILES_PROCESSED", " bestanden verwerkt."},
        {"MSG_FATAL_ERROR", "💀 FATALE FOUT: "},
        {"MSG_UNKNOWN_OPT", "❌ FOUT: Onbekende optie/pad: "},
        // Log/Actie Beschrijvingen
        {"MSG_COPYING", "📋 Kopiëren"},
        {"MSG_MOVING", "🚚 Verplaatsen"},
        {"MSG_DELETING", "🗑️ Verwijderen"},
        // Help Berichten
        {"MSG_USAGE", "Gebruik: ⚙️ ./Sort [Acties] [Opties] [Pad...]\n"},
        {"MSG_ACTIONS", "\nACTIES (Standaard: --Test):\n"},
        {"MSG_OPTIONS", "\nOPTIES:\n"},
        {"MSG_COLLISION", "\nCONFLICT AFHANDELING:\n"},
        {"MSG_FEEDBACK", "\nFEEDBACK:\n"},
        {"MSG_DESC_TEST", "Alleen simulatie"},
        {"MSG_DESC_COPY", "Kopieer bestanden"},
        {"MSG_DESC_MOVE", "Verplaats bestanden"},
        {"MSG_DESC_DELETE", "Verwijder bestanden"},
        {"MSG_DESC_TYPE", "Filter op MIME-type, bijv. image/*"},
        {"MSG_DESC_EXTENSION", "Nieuwe bestandsnaamextensie-indeling"},
        {"MSG_DESC_RENAME", "Nieuwe bestandsnaam-stam indeling"},
        {"MSG_DESC_RECURSIVE", "Verwerk submappen"},
        {"MSG_DESC_LANG", "Stel de taal van de uitvoer in (bijv. nl, en)"},
        {"MSG_DESC_VERBOSE", "Gedetailleerde loguitvoer, standaard: EN"},
        {"MSG_DESC_VERBOSE_LANG", "Gedetailleerde loguitvoer in specifieke taal"},
        {"MSG_DESC_HELP", "Toon dit helpbericht"},
        {"MSG_DESC_HELP_LANG", "Toon dit helpbericht in specifieke taal"},
        {"MSG_DESC_REPLACE", "Batch alle doelen overschrijven"},
        {"MSG_DESC_SKIP", "Batch alle bestaande doelen overslaan"},
        {"MSG_DEFAULT_COLLISION", "Standaard: #️⃣ Nummering (Hernoem met -1, -2, etc.)"},
        {"MSG_DESC_QUIET", "Onderdruk alle uitvoer behalve fouten"},
        {"MSG_DESC_TBD", "Wordt bepaald (TBD)"}
    }},
    {"en", {
        // Hoofdberichten
        {"MSG_START_ACTION", "STARTING with action: "},
        {"MSG_PATH_NOT_FOUND", "⚠️ Path not found: "},
        {"MSG_PROCESSING_DIR", "📂 Processing Dir: "},
        {"MSG_FILE_FILTERED", "🚫 MIME FILTERED: "},
        {"MSG_COLLISION_TITLE", "💥 FILE COLLISION DETECTED"},
        {"MSG_COLLISION_SRC", "➡️ Source: "},
        {"MSG_COLLISION_DST", "🎯 Target: "},
        {"MSG_COLLISION_EXISTS", " ❌ EXISTS"},
        {"MSG_COLLISION_PROMPT", "❓ Action: [C]ancel, [S]kip, S[A]kip All, [R]eplace, R[L]eplace All: "},
        {"MSG_OVERWRITE_OK", "🔄 Overwrite successful."},
        {"MSG_SKIP_OK", "⏭️ Skipped (exists)."},
        {"MSG_RENAME_OK", "#️⃣ Renamed to avoid conflict: "},
        {"MSG_CANCELED", "🚫 CANCELED by user or no files processed."},
        {"MSG_FINISHED", "✅ FINISHED: "},
        {"MSG_FILES_PROCESSED", " files processed."},
        {"MSG_FATAL_ERROR", "💀 FATAL ERROR: "},
        {"MSG_UNKNOWN_OPT", "❌ ERROR: Unknown option/path: "},
        // Log/Actie Beschrijvingen
        {"MSG_COPYING", "📋 Copying"},
        {"MSG_MOVING", "🚚 Moving"},
        {"MSG_DELETING", "🗑️ Deleting"},
        // Help Berichten
        {"MSG_USAGE", "Usage: ⚙️ ./Sort [Actions] [Options] [Paths...]\n"},
        {"MSG_ACTIONS", "\nACTIONS (Default: --Test):\n"},
        {"MSG_OPTIONS", "\nOPTIONS:\n"},
        {"MSG_COLLISION", "\nCOLLISION HANDLING:\n"},
        {"MSG_FEEDBACK", "\nFEEDBACK:\n"},
        {"MSG_DESC_TEST", "Simulation only"},
        {"MSG_DESC_COPY", "Copy files"},
        {"MSG_DESC_MOVE", "Move files"},
        {"MSG_DESC_DELETE", "Delete files"},
        {"MSG_DESC_TYPE", "Filter by MIME-type, e.g., image/*"},
        {"MSG_DESC_EXTENSION", "New file extension format"},
        {"MSG_DESC_RENAME", "New file name stem format"},
        {"MSG_DESC_RECURSIVE", "Process subdirectories"},
        {"MSG_DESC_LANG", "Set the primary output language (e.g., nl, en)"},
        {"MSG_DESC_VERBOSE", "Detailed log output, default: EN"},
        {"MSG_DESC_VERBOSE_LANG", "Detailed log output in specific language"},
        {"MSG_DESC_HELP", "Show this help message"},
        {"MSG_DESC_HELP_LANG", "Show this help message in specific language"},
        {"MSG_DESC_REPLACE", "Batch overwrite all targets"},
        {"MSG_DESC_SKIP", "Batch skip all existing targets"},
        {"MSG_DEFAULT_COLLISION", "Default: #️⃣ Numbering (Rename file with -1, -2, etc.)"},
        {"MSG_DESC_QUIET", "Silence all output but errors"},
        {"MSG_DESC_TBD", "To Be Determined (TBD)"}
    }},
    {"de", {
        // Hoofdberichten
        {"MSG_START_ACTION", "START mit Aktion: "},
        {"MSG_PATH_NOT_FOUND", "⚠️ Pfad nicht gefunden: "},
        {"MSG_PROCESSING_DIR", "📂 Verarbeite Verz: "},
        {"MSG_FILE_FILTERED", "🚫 MIME GEFILTERT: "},
        {"MSG_COLLISION_TITLE", "💥 DATEIKONFLIKT ERKANNT"},
        {"MSG_COLLISION_SRC", "➡️ Quelle: "},
        {"MSG_COLLISION_DST", "🎯 Ziel: "},
        {"MSG_COLLISION_EXISTS", " ❌ EXISTIERT BEREITS"},
        {"MSG_COLLISION_PROMPT", "❓ Aktion: [A]bbrechen, [Ü]berspringen, Überspringen [A]lle, [E]rsetzen, Ersetzen [L]le: "},
        {"MSG_OVERWRITE_OK", "🔄 Ersetzen erfolgreich."},
        {"MSG_SKIP_OK", "⏭️ Übersprungen (existiert)."},
        {"MSG_RENAME_OK", "#️⃣ Umbenannt zur Konfliktvermeidung: "},
        {"MSG_CANCELED", "🚫 ABGEBROCHEN oder keine Dateien verarbeitet."},
        {"MSG_FINISHED", "✅ BEENDET: "},
        {"MSG_FILES_PROCESSED", " Dateien verarbeitet."},
        {"MSG_FATAL_ERROR", "💀 FATALER FEHLER: "},
        {"MSG_UNKNOWN_OPT", "❌ FEHLER: Unbekannte Option/Pfad: "},
        // Log/Actie Beschrijvingen
        {"MSG_COPYING", "📋 Kopieren"},
        {"MSG_MOVING", "🚚 Verschieben"},
        {"MSG_DELETING", "🗑️ Löschen"},
        // Help Berichten
        {"MSG_USAGE", "Benutzung: ⚙️ ./Sort [Aktionen] [Optionen] [Pfad...]\n"},
        {"MSG_ACTIONS", "\nAKTIONEN (Standard: --Test):\n"},
        {"MSG_OPTIONS", "\nOPTIONEN:\n"},
        {"MSG_COLLISION", "\nKONFLIKT HANDHABUNG:\n"},
        {"MSG_FEEDBACK", "\nFEEDBACK:\n"},
        {"MSG_DESC_TEST", "Nur Simulation"},
        {"MSG_DESC_COPY", "Dateien kopieren"},
        {"MSG_DESC_MOVE", "Dateien verschieben"},
        {"MSG_DESC_DELETE", "Dateien löschen"},
        {"MSG_DESC_TYPE", "Nach MIME-Typ filtern, z.B. image/*"},
        {"MSG_DESC_EXTENSION", "Neues Dateierweiterungsformat"},
        {"MSG_DESC_RENAME", "Neues Dateinamenstammformat"},
        {"MSG_DESC_RECURSIVE", "Unterverzeichnisse verarbeiten"},
        {"MSG_DESC_LANG", "Ausgabesprache einstellen (z.B. nl, en)"},
        {"MSG_DESC_VERBOSE", "Detaillierte Protokollausgabe, Standard: EN"},
        {"MSG_DESC_VERBOSE_LANG", "Detaillierte Protokollausgabe in bestimmter Sprache"},
        {"MSG_DESC_HELP", "Diese Hilfe anzeigen"},
        {"MSG_DESC_HELP_LANG", "Diese Hilfe in bestimmter Sprache anzeigen"},
        {"MSG_DESC_REPLACE", "Alle Ziele im Batch überschreiben"},
        {"MSG_DESC_SKIP", "Alle vorhandenen Ziele im Batch überspringen"},
        {"MSG_DEFAULT_COLLISION", "Standard: #️⃣ Nummerierung (Umbenennen mit -1, -2, etc.)"},
        {"MSG_DESC_QUIET", "Alle Ausgaben außer Fehler unterdrücken"},
        {"MSG_DESC_TBD", "Wird noch festgelegt (TBD)"}
    }},
    {"fr", {
        // Hoofdberichten
        {"MSG_START_ACTION", "DÉMARRAGE avec l'action: "},
        {"MSG_PATH_NOT_FOUND", "⚠️ Chemin non trouvé: "},
        {"MSG_PROCESSING_DIR", "📂 Traitement du Rép: "},
        {"MSG_FILE_FILTERED", "🚫 MIME FILTRÉ: "},
        {"MSG_COLLISION_TITLE", "💥 COLLISION DE FICHIER DÉTECTÉE"},
        {"MSG_COLLISION_SRC", "➡️ Source: "},
        {"MSG_COLLISION_DST", "🎯 Cible: "},
        {"MSG_COLLISION_EXISTS", " ❌ EXISTE DÉJÀ"},
        {"MSG_COLLISION_PROMPT", "❓ Action: [A]nnuler, [I]gnorer, I[G]norer tout, [R]emplacer, Remplacer [T]out: "},
        {"MSG_OVERWRITE_OK", "🔄 Remplacement réussi."},
        {"MSG_SKIP_OK", "⏭️ Ignoré (existe)."},
        {"MSG_RENAME_OK", "#️⃣ Renommé pour éviter le conflit: "},
        {"MSG_CANCELED", "🚫 ANNULÉ par l'utilisateur ou aucun fichier traité."},
        {"MSG_FINISHED", "✅ TERMINÉ: "},
        {"MSG_FILES_PROCESSED", " fichiers traités."},
        {"MSG_FATAL_ERROR", "💀 ERREUR FATALE: "},
        {"MSG_UNKNOWN_OPT", "❌ ERREUR: Option/chemin inconnu: "},
        // Log/Actie Beschrijvingen
        {"MSG_COPYING", "📋 Copie"},
        {"MSG_MOVING", "🚚 Déplacement"},
        {"MSG_DELETING", "🗑️ Suppression"},
        // Help Berichten
        {"MSG_USAGE", "Utilisation: ⚙️ ./Sort [Actions] [Options] [Chemins...]\n"},
        {"MSG_ACTIONS", "\nACTIONS (Défaut: --Test):\n"},
        {"MSG_OPTIONS", "\nOPTIONS:\n"},
        {"MSG_COLLISION", "\nGESTION DES COLLISIONS:\n"},
        {"MSG_FEEDBACK", "\nCOMMENTAIRES:\n"},
        {"MSG_DESC_TEST", "Simulation seulement"},
        {"MSG_DESC_COPY", "Copier les fichiers"},
        {"MSG_DESC_MOVE", "Déplacer les fichiers"},
        {"MSG_DESC_DELETE", "Supprimer les fichiers"},
        {"MSG_DESC_TYPE", "Filtrer par type MIME, ex. image/*"},
        {"MSG_DESC_EXTENSION", "Nouveau format d'extension de nom de fichier"},
        {"MSG_DESC_RENAME", "Nouveau format de nom de fichier souche"},
        {"MSG_DESC_RECURSIVE", "Traiter les sous-répertoires"},
        {"MSG_DESC_LANG", "Définir la langue de sortie principale (ex. nl, en)"},
        {"MSG_DESC_VERBOSE", "Sortie de journal détaillée, par défaut: EN"},
        {"MSG_DESC_VERBOSE_LANG", "Sortie de journal détaillée dans une langue spécifique"},
        {"MSG_DESC_HELP", "Afficher ce message d'aide"},
        {"MSG_DESC_HELP_LANG", "Afficher ce message d'aide dans une langue spécifique"},
        {"MSG_DESC_REPLACE", "Remplacer toutes les cibles par lot"},
        {"MSG_DESC_SKIP", "Ignorer toutes les cibles existantes par lot"},
        {"MSG_DEFAULT_COLLISION", "Défaut: #️⃣ Numérotation (Renommer le fichier avec -1, -2, etc.)"},
        {"MSG_DESC_QUIET", "Masquer toutes les sorties sauf les erreurs"},
        {"MSG_DESC_TBD", "À Déterminer (TBD)"}
    }},
    {"jp", { // Japans
        // Hoofdberichten
        {"MSG_START_ACTION", "処理を開始: "},
        {"MSG_PATH_NOT_FOUND", "⚠️ パスが見つかりません: "},
        {"MSG_PROCESSING_DIR", "📂 ディレクトリ処理中: "},
        {"MSG_FILE_FILTERED", "🚫 MIMEフィルタリング: "},
        {"MSG_COLLISION_TITLE", "💥 ファイルの衝突を検出"},
        {"MSG_COLLISION_SRC", "➡️ ソース: "},
        {"MSG_COLLISION_DST", "🎯 ターゲット: "},
        {"MSG_COLLISION_EXISTS", " ❌ 既に存在します"},
        {"MSG_COLLISION_PROMPT", "❓ アクション: [C]ancel, [S]kip, S[A]kip All, [R]eplace, R[L]eplace All: "},
        {"MSG_OVERWRITE_OK", "🔄 上書き成功。"},
        {"MSG_SKIP_OK", "⏭️ スキップしました (既存)。"},
        {"MSG_RENAME_OK", "#️⃣ 衝突回避のため名前を変更: "},
        {"MSG_CANCELED", "🚫 ユーザーによりキャンセルまたはファイル処理なし。"},
        {"MSG_FINISHED", "✅ 完了: "},
        {"MSG_FILES_PROCESSED", " ファイルを処理しました。"},
        {"MSG_FATAL_ERROR", "💀 致命的なエラー: "},
        {"MSG_UNKNOWN_OPT", "❌ エラー: 不明なオプション/パス: "},
        // Log/Actie Beschrijvingen
        {"MSG_COPYING", "📋 コピー中"},
        {"MSG_MOVING", "🚚 移動中"},
        {"MSG_DELETING", "🗑️ 削除中"},
        // Help Berichten
        {"MSG_USAGE", "使用法: ⚙️ ./Sort [アクション] [オプション] [パス...]\n"},
        {"MSG_ACTIONS", "\nアクション (デフォルト: --Test):\n"},
        {"MSG_OPTIONS", "\nオプション:\n"},
        {"MSG_COLLISION", "\n衝突処理:\n"},
        {"MSG_FEEDBACK", "\nフィードバック:\n"},
        {"MSG_DESC_TEST", "シミュレーションのみ"},
        {"MSG_DESC_COPY", "ファイルをコピー"},
        {"MSG_DESC_MOVE", "ファイルを移動"},
        {"MSG_DESC_DELETE", "ファイルを削除"},
        {"MSG_DESC_TYPE", "MIMEタイプでフィルタリング, 例: image/*"},
        {"MSG_DESC_EXTENSION", "新しいファイル拡張子形式"},
        {"MSG_DESC_RENAME", "新しいファイル名ステム形式"},
        {"MSG_DESC_RECURSIVE", "サブディレクトリを処理"},
        {"MSG_DESC_LANG", "主要な出力言語を設定 (例: nl, en)"},
        {"MSG_DESC_VERBOSE", "詳細なログ出力, デフォルト: EN"},
        {"MSG_DESC_VERBOSE_LANG", "特定の言語での詳細なログ出力"},
        {"MSG_DESC_HELP", "このヘルプメッセージを表示"},
        {"MSG_DESC_HELP_LANG", "特定の言語でこのヘルプメッセージを表示"},
        {"MSG_DESC_REPLACE", "すべての一括上書き"},
        {"MSG_DESC_SKIP", "すべての既存ターゲットを一括スキップ"},
        {"MSG_DEFAULT_COLLISION", "デフォルト: #️⃣ ナンバリング (-1, -2 などでリネーム)"},
        {"MSG_DESC_QUIET", "エラーを除くすべての出力を抑制"},
        {"MSG_DESC_TBD", "未定 (TBD)"}
    }},
    {"ar", { // Arabisch
        // Hoofdberichten
        {"MSG_START_ACTION", "بدء الإجراء: "},
        {"MSG_PATH_NOT_FOUND", "⚠️ المسار غير موجود: "},
        {"MSG_PROCESSING_DIR", "📂 معالجة الدليل: "},
        {"MSG_FILE_FILTERED", "🚫 MIME تمت التصفية: "},
        {"MSG_COLLISION_TITLE", "💥 تم اكتشاف تعارض في الملفات"},
        {"MSG_COLLISION_SRC", "➡️ المصدر: "},
        {"MSG_COLLISION_DST", "🎯 الهدف: "},
        {"MSG_COLLISION_EXISTS", " ❌ موجود بالفعل"},
        {"MSG_COLLISION_PROMPT", "❓ الإجراء: [C]ancel, [S]kip, S[A]kip All, [R]eplace, R[L]eplace All: "},
        {"MSG_OVERWRITE_OK", "🔄 تم التجاوز بنجاح."},
        {"MSG_SKIP_OK", "⏭️ تم التخطي (موجود)."},
        {"MSG_RENAME_OK", "#️⃣ تمت إعادة التسمية لتجنب التعارض: "},
        {"MSG_CANCELED", "🚫 تم الإلغاء بواسطة المستخدم أو لا توجد ملفات تمت معالجتها."},
        {"MSG_FINISHED", "✅ انتهى: "},
        {"MSG_FILES_PROCESSED", " ملف تمت معالجته."},
        {"MSG_FATAL_ERROR", "💀 خطأ فادح: "},
        {"MSG_UNKNOWN_OPT", "❌ خطأ: خيار/مسار غير معروف: "},
        // Log/Actie Beschrijvingen
        {"MSG_COPYING", "📋 نسخ"},
        {"MSG_MOVING", "🚚 نقل"},
        {"MSG_DELETING", "🗑️ حذف"},
        // Help Berichten
        {"MSG_USAGE", "الاستخدام: ⚙️ ./Sort [الإجراءات] [الخيارات] [المسارات...]\n"},
        {"MSG_ACTIONS", "\nالإجراءات (افتراضي: --Test):\n"},
        {"MSG_OPTIONS", "\nالخيارات:\n"},
        {"MSG_COLLISION", "\nمعالجة التعارض:\n"},
        {"MSG_FEEDBACK", "\nالتغذية الراجعة:\n"},
        {"MSG_DESC_TEST", "محاكاة فقط"},
        {"MSG_DESC_COPY", "نسخ الملفات"},
        {"MSG_DESC_MOVE", "نقل الملفات"},
        {"MSG_DESC_DELETE", "حذف الملفات"},
        {"MSG_DESC_TYPE", "التصفية حسب نوع MIME، على سبيل المثال image/*"},
        {"MSG_DESC_EXTENSION", "تنسيق ملحق اسم الملف الجديد"},
        {"MSG_DESC_RENAME", "تنسيق جذر اسم الملف الجديد"},
        {"MSG_DESC_RECURSIVE", "معالجة الأدلة الفرعية"},
        {"MSG_DESC_LANG", "تعيين لغة الإخراج الأساسية (على سبيل المثال nl, en)"},
        {"MSG_DESC_VERBOSE", "إخراج سجل مفصل، الافتراضي: EN"},
        {"MSG_DESC_VERBOSE_LANG", "إخراج سجل مفصل بلغة محددة"},
        {"MSG_DESC_HELP", "عرض رسالة المساعدة هذه"},
        {"MSG_DESC_HELP_LANG", "عرض رسالة المساعدة هذه بلغة محددة"},
        {"MSG_DESC_REPLACE", "تجاوز كافة الأهداف دفعة واحدة"},
        {"MSG_DESC_SKIP", "تخطي جميع الأهداف الموجودة دفعة واحدة"},
        {"MSG_DEFAULT_COLLISION", "الافتراضي: #️⃣ ترقيم (إعادة تسمية الملف باستخدام -1، -2، إلخ)"},
        {"MSG_DESC_QUIET", "إسكات كل المخرجات ما عدا الأخطاء"},
        {"MSG_DESC_TBD", "سيتم تحديده لاحقًا (TBD)"}
    }},
    {"ru", { // Russisch
        // Hoofdberichten
        {"MSG_START_ACTION", "НАЧАЛО выполнения действия: "},
        {"MSG_PATH_NOT_FOUND", "⚠️ Путь не найден: "},
        {"MSG_PROCESSING_DIR", "📂 Обработка каталога: "},
        {"MSG_FILE_FILTERED", "🚫 MIME отфильтровано: "},
        {"MSG_COLLISION_TITLE", "💥 ОБНАРУЖЕНО КОНФЛИКТ ФАЙЛОВ"},
        {"MSG_COLLISION_SRC", "➡️ Источник: "},
        {"MSG_COLLISION_DST", "🎯 Цель: "},
        {"MSG_COLLISION_EXISTS", " ❌ УЖЕ СУЩЕСТВУЕТ"},
        {"MSG_COLLISION_PROMPT", "❓ Действие: [О]тмена, [П]ропустить, Пр[А]пустить все, [З]аменить, Заме[Н]ить все: "},
        {"MSG_OVERWRITE_OK", "🔄 Перезапись успешна."},
        {"MSG_SKIP_OK", "⏭️ Пропущено (существует)."},
        {"MSG_RENAME_OK", "#️⃣ Переименовано, чтобы избежать конфликта: "},
        {"MSG_CANCELED", "🚫 ОТМЕНЕНО пользователем или нет обработанных файлов."},
        {"MSG_FINISHED", "✅ ЗАВЕРШЕНО: "},
        {"MSG_FILES_PROCESSED", " файлов обработано."},
        {"MSG_FATAL_ERROR", "💀 ФАТАЛЬНАЯ ОШИБКА: "},
        {"MSG_UNKNOWN_OPT", "❌ ОШИБКА: Неизвестная опция/путь: "},
        // Log/Actie Beschrijvingen
        {"MSG_COPYING", "📋 Копирование"},
        {"MSG_MOVING", "🚚 Перемещение"},
        {"MSG_DELETING", "🗑️ Удаление"},
        // Help Berichten
        {"MSG_USAGE", "Использование: ⚙️ ./Sort [Действия] [Опции] [Пути...]\n"},
        {"MSG_ACTIONS", "\nДЕЙСТВИЯ (По умолчанию: --Test):\n"},
        {"MSG_OPTIONS", "\nОПЦИИ:\n"},
        {"MSG_COLLISION", "\nОБРАБОТКА КОНФЛИКТОВ:\n"},
        {"MSG_FEEDBACK", "\nОБРАТНАЯ СВЯЗЬ:\n"},
        {"MSG_DESC_TEST", "Только симуляция"},
        {"MSG_DESC_COPY", "Копировать файлы"},
        {"MSG_DESC_MOVE", "Перемещать файлы"},
        {"MSG_DESC_DELETE", "Удалить файлы"},
        {"MSG_DESC_TYPE", "Фильтровать по типу MIME, например image/*"},
        {"MSG_DESC_EXTENSION", "Новый формат расширения имени файла"},
        {"MSG_DESC_RENAME", "Новый формат основы имени файла"},
        {"MSG_DESC_RECURSIVE", "Обрабатывать подкаталоги"},
        {"MSG_DESC_LANG", "Установить основной язык вывода (например, nl, en)"},
        {"MSG_DESC_VERBOSE", "Подробный вывод журнала, по умолчанию: EN"},
        {"MSG_DESC_VERBOSE_LANG", "Подробный вывод журнала на определенном языке"},
        {"MSG_DESC_HELP", "Показать это справочное сообщение"},
        {"MSG_DESC_HELP_LANG", "Показать это справочное сообщение на определенном языке"},
        {"MSG_DESC_REPLACE", "Пакетная перезапись всех целей"},
        {"MSG_DESC_SKIP", "Пакетный пропуск всех существующих целей"},
        {"MSG_DEFAULT_COLLISION", "По умолчанию: #️⃣ Нумерация (Переименовать файл с -1, -2 и т.д.)"},
        {"MSG_DESC_QUIET", "Подавлять весь вывод, кроме ошибок"},
        {"MSG_DESC_TBD", "Будет определено (TBD)"}
    }},
    {"tr", { // Turks
        // Hoofdberichten
        {"MSG_START_ACTION", "İŞLEME BAŞLANIYOR: "},
        {"MSG_PATH_NOT_FOUND", "⚠️ Yol bulunamadı: "},
        {"MSG_PROCESSING_DIR", "📂 Dizin İşleniyor: "},
        {"MSG_FILE_FILTERED", "🚫 MIME FİLTRELENDİ: "},
        {"MSG_COLLISION_TITLE", "💥 DOSYA ÇAKIŞMASI TESPİT EDİLDİ"},
        {"MSG_COLLISION_SRC", "➡️ Kaynak: "},
        {"MSG_COLLISION_DST", "🎯 Hedef: "},
        {"MSG_COLLISION_EXISTS", " ❌ ZATEN MEVCUT"},
        {"MSG_COLLISION_PROMPT", "❓ Eylem: [İ]ptal, [A]tla, Hepsini [A]tla, [Y]az, Tümünü [Y]az: "},
        {"MSG_OVERWRITE_OK", "🔄 Üzerine yazma başarılı."},
        {"MSG_SKIP_OK", "⏭️ Atlandı (mevcut)."},
        {"MSG_RENAME_OK", "#️⃣ Çakışmayı önlemek için yeniden adlandırıldı: "},
        {"MSG_CANCELED", "🚫 Kullanıcı tarafından İPTAL EDİLDİ veya dosya işlenmedi."},
        {"MSG_FINISHED", "✅ TAMAMLANDI: "},
        {"MSG_FILES_PROCESSED", " dosya işlendi."},
        {"MSG_FATAL_ERROR", "💀 KRİTİK HATA: "},
        {"MSG_UNKNOWN_OPT", "❌ HATA: Bilinmeyen seçenek/yol: "},
        // Log/Actie Beschrijvingen
        {"MSG_COPYING", "📋 Kopyalanıyor"},
        {"MSG_MOVING", "🚚 Taşınıyor"},
        {"MSG_DELETING", "🗑️ Siliniyor"},
        // Help Berichten
        {"MSG_USAGE", "Kullanım: ⚙️ ./Sort [Eylemler] [Seçenekler] [Yollar...]\n"},
        {"MSG_ACTIONS", "\nEYLEMLER (Varsayılan: --Test):\n"},
        {"MSG_OPTIONS", "\nSEÇENEKLER:\n"},
        {"MSG_COLLISION", "\nÇAKIŞMA İŞLEMESİ:\n"},
        {"MSG_FEEDBACK", "\nGERİ BİLDİRİM:\n"},
        {"MSG_DESC_TEST", "Yalnızca simülasyon"},
        {"MSG_DESC_COPY", "Dosyaları kopyala"},
        {"MSG_DESC_MOVE", "Dosyaları taşı"},
        {"MSG_DESC_DELETE", "Dosyaları sil"},
        {"MSG_DESC_TYPE", "MIME türüne göre filtrele, örn. image/*"},
        {"MSG_DESC_EXTENSION", "Yeni dosya uzantısı formatı"},
        {"MSG_DESC_RENAME", "Yeni dosya adı kök formatı"},
        {"MSG_DESC_RECURSIVE", "Alt dizinleri işle"},
        {"MSG_DESC_LANG", "Birincil çıktı dilini ayarla (örn. nl, en)"},
        {"MSG_DESC_VERBOSE", "Ayrıntılı günlük çıktısı, varsayılan: EN"},
        {"MSG_DESC_VERBOSE_LANG", "Belirli dilde ayrıntılı günlük çıktısı"},
        {"MSG_DESC_HELP", "Bu yardım mesajını göster"},
        {"MSG_DESC_HELP_LANG", "Bu yardım mesajını belirli dilde göster"},
        {"MSG_DESC_REPLACE", "Tüm hedefleri toplu olarak üzerine yaz"},
        {"MSG_DESC_SKIP", "Mevcut tüm hedefleri toplu olarak atla"},
        {"MSG_DEFAULT_COLLISION", "Varsayılan: #️⃣ Numaralandırma (-1, -2 vb. ile yeniden adlandır)"},
        {"MSG_DESC_QUIET", "Hatalar dışındaki tüm çıktıları sustur"},
        {"MSG_DESC_TBD", "Belirlenecek (TBD)"}
    }},
    {"zh", { // Chinees (Mandarijn, Vereenvoudigd)
        // Hoofdberichten
        {"MSG_START_ACTION", "开始执行操作: "},
        {"MSG_PATH_NOT_FOUND", "⚠️ 路径未找到: "},
        {"MSG_PROCESSING_DIR", "📂 正在处理目录: "},
        {"MSG_FILE_FILTERED", "🚫 MIME 已过滤: "},
        {"MSG_COLLISION_TITLE", "💥 检测到文件冲突"},
        {"MSG_COLLISION_SRC", "➡️ 源: "},
        {"MSG_COLLISION_DST", "🎯 目标: "},
        {"MSG_COLLISION_EXISTS", " ❌ 已存在"},
        {"MSG_COLLISION_PROMPT", "❓ 操作: [C]ancel, [S]kip, S[A]kip All, [R]eplace, R[L]eplace All: "},
        {"MSG_OVERWRITE_OK", "🔄 覆盖成功。"},
        {"MSG_SKIP_OK", "⏭️ 已跳过 (已存在)。"},
        {"MSG_RENAME_OK", "#️⃣ 为避免冲突已重命名: "},
        {"MSG_CANCELED", "🚫 被用户取消或未处理任何文件。"},
        {"MSG_FINISHED", "✅ 完成: "},
        {"MSG_FILES_PROCESSED", " 个文件已处理。"},
        {"MSG_FATAL_ERROR", "💀 致命错误: "},
        {"MSG_UNKNOWN_OPT", "❌ 错误: 未知选项/路径: "},
        // Log/Actie Beschrijvingen
        {"MSG_COPYING", "📋 复制中"},
        {"MSG_MOVING", "🚚 移动中"},
        {"MSG_DELETING", "🗑️ 删除中"},
        // Help Berichten
        {"MSG_USAGE", "用法: ⚙️ ./Sort [操作] [选项] [路径...]\n"},
        {"MSG_ACTIONS", "\n操作 (默认: --Test):\n"},
        {"MSG_OPTIONS", "\n选项:\n"},
        {"MSG_COLLISION", "\n冲突处理:\n"},
        {"MSG_FEEDBACK", "\n反馈:\n"},
        {"MSG_DESC_TEST", "仅模拟"},
        {"MSG_DESC_COPY", "复制文件"},
        {"MSG_DESC_MOVE", "移动文件"},
        {"MSG_DESC_DELETE", "删除文件"},
        {"MSG_DESC_TYPE", "按 MIME 类型过滤, 例如 image/*"},
        {"MSG_DESC_EXTENSION", "新文件扩展名格式"},
        {"MSG_DESC_RENAME", "新文件名词干格式"},
        {"MSG_DESC_RECURSIVE", "处理子目录"},
        {"MSG_DESC_LANG", "设置主要输出语言 (例如 nl, en)"},
        {"MSG_DESC_VERBOSE", "详细日志输出, 默认: EN"},
        {"MSG_DESC_VERBOSE_LANG", "特定语言的详细日志输出"},
        {"MSG_DESC_HELP", "显示此帮助信息"},
        {"MSG_DESC_HELP_LANG", "显示特定语言的帮助信息"},
        {"MSG_DESC_REPLACE", "批量覆盖所有目标"},
        {"MSG_DESC_SKIP", "批量跳过所有现有目标"},
        {"MSG_DEFAULT_COLLISION", "默认: #️⃣ 编号 (-1, -2 等重命名)"},
        {"MSG_DESC_QUIET", "除错误外, 静默所有输出"},
        {"MSG_DESC_TBD", "待定 (TBD)"}
    }}
    // ... (Andere talen zouden hier volgen)
};

std::string g_current_lang = "nl"; 

/**
 * Zoek de vertaling voor de hoofdoutput.
 */
const std::string& T(const std::string& key) {
    if (g_translations.count(g_current_lang) && g_translations.at(g_current_lang).count(key)) {
        return g_translations.at(g_current_lang).at(key);
    }
    if (g_translations.count("en") && g_translations.at("en").count(key)) {
        return g_translations.at("en").at(key);
    }
    static const std::string fallback_key = key; 
    return fallback_key;
}

/**
 * Zoek de vertaling voor de log output.
 */
const std::string& T_log(const std::string& key, const std::string& log_lang) {
    if (g_translations.count(log_lang) && g_translations.at(log_lang).count(key)) {
        return g_translations.at(log_lang).at(key);
    }
    if (g_translations.count("en") && g_translations.at("en").count(key)) {
        return g_translations.at("en").at(key);
    }
    static const std::string fallback_key = key; 
    return fallback_key;
}


// =========================================================================
// 2. STRUCTUREN EN ENUMS (ONGEDEF)
// =========================================================================

enum class Action {
    None, Copy, Move, Delete, Test 
};

enum class CollisionStrategy {
    Number,           
    Replace,          
    Skip,             
    Interactive       
};

enum class InteractiveAction {
    Ask,               
    SkipSingle,        
    SkipAll,           
    OverwriteSingle,   
    OverwriteAll,      
    Cancel             
};


struct SortOptions {
    Action action = Action::Test; 
    string mime_types = "";
    bool recursive = false;
    CollisionStrategy collision_strategy = CollisionStrategy::Number;
    string rename_format = "original";
    string dirs_format = "original";
    string subdirs_format = "original";
    
    string extension_format = "original"; 
    
    bool verbose = false; 
    bool quiet = false;
    
    vector<string> paths;
    
    string log_lang = "nl"; 
};

// Prototypes
int execute_sort(const SortOptions& options);
string generate_new_filename(const fs::path& original_path, const SortOptions& options);

// ... (Helper functies zoals sha256_file, get_file_time_string, get_mime_type, etc. zijn weggelaten)

// Functie voor MIME-filtering (simulatie van implementatie)
bool matches_mime_filter(const fs::path& path, const string& filter_string) {
    if (filter_string.empty()) return true;
    return true; 
}

// Functie om nieuwe bestandsnaam (stam) te bepalen (simulatie van implementatie)
string generate_new_filename(const fs::path& original_path, const SortOptions& options) {
    if (options.rename_format == "original" || options.rename_format.empty()) {
        return original_path.filename().string(); 
    }
    return options.rename_format + original_path.extension().string(); 
}

// =========================================================================
// 3. INTERACTIEVE FUNCTIES
// =========================================================================

/**
 * Vraagt de gebruiker om een actie te kiezen bij een botsing.
 */
InteractiveAction handle_interactive_collision(
    const fs::path& source, 
    const fs::path& target
) {
    cout << "\n" << T("MSG_COLLISION_TITLE") << " 💥" << endl;
    cout << T("MSG_COLLISION_SRC") << source.filename().string() << endl;
    cout << T("MSG_COLLISION_DST") << target.filename().string() << T("MSG_COLLISION_EXISTS") << endl;
    cout << T("MSG_COLLISION_PROMPT");
    
    string input;
    if (getline(cin, input) && !input.empty()) {
        char choice = tolower(input[0]);
        // Controle op de eerste letter (NL/EN/DE/FR/RU/TR)
        if (choice == 'a' || choice == 'c' || choice == 'o') { 
            return InteractiveAction::Cancel; // Annuleren/Cancel/Otmena
        } else if (choice == 'o' || choice == 's' || choice == 'p' || choice == 'i') { 
            if (input.size() > 1 && (tolower(input[1]) == 'a' || tolower(input[1]) == 'l' || tolower(input[1]) == 'g')) { 
                return InteractiveAction::SkipAll;
            }
            return InteractiveAction::SkipSingle;
        } else if (choice == 'v' || choice == 'r' || choice == 'z' || choice == 'e' || choice == 'y') { 
            if (input.size() > 1 && (tolower(input[1]) == 'a' || tolower(input[1]) == 'l' || tolower(input[1]) == 'n' || tolower(input[1]) == 't')) { 
                return InteractiveAction::OverwriteAll;
            }
            return InteractiveAction::OverwriteSingle;
        }
    }
    return InteractiveAction::SkipSingle; 
}

// =========================================================================
// 4. HOOFDLOGICA FUNCTIES
// =========================================================================

/**
 * Verwerkt een enkel bestand. Geeft 1 terug bij succes, 0 anders.
 */
int process_file(
    const fs::path& source_path, 
    const SortOptions& options, 
    InteractiveAction& current_interactive_action, 
    bool& execution_cancelled                      
) {
    if (execution_cancelled) return 0;
    
    auto log = [&](const string& message) {
        if (options.verbose && !options.quiet) {
            cout << message << endl;
        }
    };
    
    string action_sym;
    bool simulation = false;
    
    switch (options.action) {
        case Action::Copy: action_sym = T_log("MSG_COPYING", options.log_lang); break;
        case Action::Move: action_sym = T_log("MSG_MOVING", options.log_lang); break;
        case Action::Delete: action_sym = T_log("MSG_DELETING", options.log_lang); break;
        case Action::Test: 
        default: 
            action_sym = "🔬 SIMULATION"; 
            simulation = true; 
            break;
    }

    if (options.action == Action::Delete) {
        if (!simulation) { /* fs::remove(source_path); */ }
        log(action_sym + ": " + source_path.string());
        return 1;
    }

    string new_filename = generate_new_filename(source_path, options);
    fs::path target_dir = "/tmp/SortedFiles/"; 

    fs::path target_path = target_dir / new_filename;
    
    CollisionStrategy current_strategy = options.collision_strategy;

    if (fs::exists(target_path) && !simulation) { 
        
        if (options.collision_strategy == CollisionStrategy::Interactive) {
            
            InteractiveAction chosen_action = current_interactive_action;

            if (chosen_action == InteractiveAction::Ask || chosen_action == InteractiveAction::SkipSingle || chosen_action == InteractiveAction::OverwriteSingle) {
                chosen_action = handle_interactive_collision(source_path, target_path);
                current_interactive_action = chosen_action;
            }
            
            if (chosen_action == InteractiveAction::SkipSingle || chosen_action == InteractiveAction::SkipAll) {
                current_strategy = CollisionStrategy::Skip;
            } else if (chosen_action == InteractiveAction::OverwriteSingle || chosen_action == InteractiveAction::OverwriteAll) {
                current_strategy = CollisionStrategy::Replace;
            } else if (chosen_action == InteractiveAction::Cancel) {
                execution_cancelled = true;
                return 0;
            } else {
                 current_strategy = CollisionStrategy::Number;
            }
        } 

        if (current_strategy == CollisionStrategy::Replace) {
            if (!simulation) { /* fs::remove(target_path); */ }
            log("  > " + T_log("MSG_OVERWRITE_OK", options.log_lang));
        } else if (current_strategy == CollisionStrategy::Skip) {
            log("  > " + T_log("MSG_SKIP_OK", options.log_lang));
            return 0; 
        } else { 
            // Nummering (CollisionStrategy::Number)
            int counter = 1;
            fs::path numbered_path;
            do {
                numbered_path = target_dir / (target_path.stem().string() + "-" + std::to_string(counter++) + target_path.extension().string());
            } while (fs::exists(numbered_path));
            target_path = numbered_path;
            log("  > " + T_log("MSG_RENAME_OK", options.log_lang) + target_path.filename().string());
        }
    }

    if (options.action == Action::Test) {
        cout << "🧪 TEST: " << source_path.string() << " >> " << target_path.string() << endl;
    }
    else if (options.action == Action::Copy || options.action == Action::Move) {
        // ... (Simulatie van fs::copy of fs::rename)
        log("  > " + action_sym + " to " + target_path.string());
    }

    return 1;
}

/**
 * Loop door alle paden en bestanden.
 */
int execute_sort(const SortOptions& options) {
    int processed_count = 0;
    
    InteractiveAction current_interactive_action = InteractiveAction::Ask;
    bool execution_cancelled = false;

    for (const auto& path_str : options.paths) {
        if (execution_cancelled) break;
        fs::path entry_path(path_str);

        if (!fs::exists(entry_path)) {
            if (!options.quiet) { 
                cerr << T("MSG_PATH_NOT_FOUND") << path_str << endl;
            }
            continue;
        }
        
        if (options.action == Action::Delete) {
             processed_count += process_file(entry_path, options, current_interactive_action, execution_cancelled);
             continue;
        }

        auto process_entry = [&](const fs::path& current_path) {
            if (execution_cancelled) return;

            if (fs::is_regular_file(current_path)) {
                if (matches_mime_filter(current_path, options.mime_types)) {
                    processed_count += process_file(current_path, options, current_interactive_action, execution_cancelled);
                } else {
                    if (options.verbose && !options.quiet) { 
                        cout << "  > " << T_log("MSG_FILE_FILTERED", options.log_lang) << current_path.filename().string() << endl;
                    }
                }
            }
        };

        if (fs::is_directory(entry_path)) {
            if (options.verbose && !options.quiet) { cout << T_log("MSG_PROCESSING_DIR", options.log_lang) << path_str << (options.recursive ? " (recursive)" : "") << endl; }
            if (options.recursive) {
                for (const auto& entry : fs::recursive_directory_iterator(entry_path)) {
                    if (execution_cancelled) break;
                    process_entry(entry.path());
                }
            } else {
                for (const auto& entry : fs::directory_iterator(entry_path)) {
                    if (execution_cancelled) break;
                    process_entry(entry.path());
                }
            }
        } else if (fs::is_regular_file(entry_path)) {
            process_entry(entry_path);
        }
    }

    return processed_count;
}

// =========================================================================
// 5. PRINT HELP FUNCTIE
// =========================================================================

/**
 * Drukt de helptekst af in de opgegeven taal.
 */
void print_help(const std::string& lang_code) {
    // Lokale lambda functie om vertaling op te halen met de gevraagde taalcode
    auto T_help = [&](const string& key) -> const string& {
        if (g_translations.count(lang_code) && g_translations.at(lang_code).count(key)) {
            return g_translations.at(lang_code).at(key);
        }
        if (g_translations.count("en") && g_translations.at("en").count(key)) {
            return g_translations.at("en").at(key);
        }
        static const string fallback = key;
        return fallback;
    };

    cout << T_help("MSG_USAGE");
    cout << T_help("MSG_ACTIONS");
    cout << "  --Test          (🔬 " << T_help("MSG_DESC_TEST") << ")\n"
         << "  --Copy          (📋 " << T_help("MSG_DESC_COPY") << ")\n"
         << "  --Move          (🚚 " << T_help("MSG_DESC_MOVE") << ")\n"
         << "  --Delete        (🗑️ " << T_help("MSG_DESC_DELETE") << ")\n";
    cout << T_help("MSG_OPTIONS");
    cout << "  --Type=[mimes]  (" << T_help("MSG_DESC_TYPE") << ")\n"
         << "  --Extension=[f] (" << T_help("MSG_DESC_EXTENSION") << ")\n"
         << "  --Rename=[f]    (" << T_help("MSG_DESC_RENAME") << ")\n"
         << "  --Recursive     (🔄 " << T_help("MSG_DESC_RECURSIVE") << ")\n"
         << "  --Lang=[xx]     (🌐 " << T_help("MSG_DESC_LANG") << ")\n";
    cout << "  --Verbose       (➕ " << T_help("MSG_DESC_VERBOSE") << ")\n"
         << "  --Verbose=[xx]  (➕ " << T_help("MSG_DESC_VERBOSE_LANG") << ")\n"; 
    cout << "  --Help          (❓ " << T_help("MSG_DESC_HELP") << ")\n"
         << "  --Help=[xx]     (❓ " << T_help("MSG_DESC_HELP_LANG") << ")\n";
    cout << T_help("MSG_COLLISION");
    cout << "  --Replace       (🔄 " << T_help("MSG_DESC_REPLACE") << ")\n"
         << "  --Skip          (⏭️ " << T_help("MSG_DESC_SKIP") << ")\n"
         << "  (" << T_help("MSG_DEFAULT_COLLISION") << ")\n";
    cout << T_help("MSG_FEEDBACK");
    cout << "  --Quiet         (➖ " << T_help("MSG_DESC_QUIET") << ")\n"
         << "  --Dirs=[f] (" << T_help("MSG_DESC_TBD") << ")\n"
         << "  --SubDirs=[f] (" << T_help("MSG_DESC_TBD") << ")\n"
         << endl;
}

// =========================================================================
// 6. MAIN FUNCTIE (Parsing)
// =========================================================================

int main(int argc, char* argv[]) {
    if (argc < 2) {
        print_help(g_current_lang);
        return 1;
    }

    SortOptions options;
    bool explicit_collision_strategy = false;

    // EERSTE PARSING LUS: Verwerk directe opdrachten zoals --Help en --Lang (voor de helptekst)
    for (int i = 1; i < argc; ++i) {
        string arg = argv[i];
        
        if (arg.rfind("--Lang=", 0) == 0) {
            g_current_lang = arg.substr(7);
            if (g_translations.find(g_current_lang) == g_translations.end()) {
                g_current_lang = "nl"; 
            }
        } 
        
        // HULP OPROEP IN SPECIFIEKE TAAL OF STANDAARD
        if (arg.rfind("--Help=", 0) == 0) {
            string help_lang = arg.substr(7);
            print_help(help_lang);
            return 0; 
        } else if (arg == "--Help") {
             print_help(g_current_lang);
             return 0; 
        }
    }
    
    // TWEEDE PARSING LUS: Verwerk alle uitvoerende argumenten
    for (int i = 1; i < argc; ++i) {
        string arg = argv[i];

        if (arg == "--Copy") {
            options.action = Action::Copy;
        } else if (arg == "--Move") {
            options.action = Action::Move;
        } else if (arg == "--Delete") {
            options.action = Action::Delete;
        } else if (arg == "--Test") {
            options.action = Action::Test;
        } else if (arg == "--Recursive") {
            options.recursive = true;
        } else if (arg == "--Replace") {
            options.collision_strategy = CollisionStrategy::Replace;
            explicit_collision_strategy = true;
        } else if (arg == "--Skip") {
            options.collision_strategy = CollisionStrategy::Skip;
            explicit_collision_strategy = true;
        } else if (arg == "--Verbose") {
            options.verbose = true;
            options.log_lang = "en"; 
        } else if (arg.rfind("--Verbose=", 0) == 0) {
            options.verbose = true;
            options.log_lang = arg.substr(10);
            if (g_translations.find(options.log_lang) == g_translations.end()) {
                options.log_lang = "en"; 
            }
        } else if (arg == "--Quiet") {
            options.quiet = true;
        } else if (arg.rfind("--Lang=", 0) == 0) {
            // Reeds verwerkt in lus 1, maar moet hier de globale taal bijwerken
            // Logische synchronisatie is vereist
        } else if (arg.rfind("--Type=", 0) == 0) {
            options.mime_types = arg.substr(7);
        } else if (arg.rfind("--Rename=", 0) == 0) {
            options.rename_format = arg.substr(9);
        } else if (arg.rfind("--Extension=", 0) == 0) { 
            options.extension_format = arg.substr(12);
        } else if (arg.rfind("--Dirs=", 0) == 0) {
            options.dirs_format = arg.substr(7);
        } else if (arg.rfind("--SubDirs=", 0) == 0) {
            options.subdirs_format = arg.substr(10);
        } else if (arg.rfind("--", 0) != 0) {
            options.paths.push_back(arg);
        } else {
            cerr << T("MSG_UNKNOWN_OPT") << arg << endl;
            return 1;
        }
    }

    // Synchronisatie van Logtaal als geen expliciete --Verbose werd gebruikt
    if (!options.verbose) {
        options.log_lang = g_current_lang;
    }

    if (options.quiet) {
        options.verbose = false;
    }
    
    bool rename_is_literal = (
        options.rename_format != "original" && 
        options.rename_format != "sha256sum" && 
        options.rename_format != "modified-date" && 
        options.rename_format != "modified-time"
    );
    
    if (rename_is_literal && !explicit_collision_strategy && options.action != Action::Test) {
         options.collision_strategy = CollisionStrategy::Interactive;
    }

    
    try {
        string action_sym;
        switch (options.action) {
            case Action::Copy: action_sym = "📋 Copy"; break;
            case Action::Move: action_sym = "🚚 Move"; break;
            case Action::Delete: action_sym = "🗑️ Delete"; break;
            case Action::Test: action_sym = "🔬 TEST (Simulation)"; break;
            default: action_sym = "❓ Unknown"; break;
        }

        if (!options.quiet) {
            cout << "✨ " << T("MSG_START_ACTION") << action_sym << endl;
        }
        
        int files_processed = execute_sort(options);
        
        if (!options.quiet) {
             if (files_processed > 0 || options.paths.empty()) {
                cout << T("MSG_FINISHED") << files_processed << T("MSG_FILES_PROCESSED") << endl;
            } else {
                cout << T("MSG_CANCELED") << endl; 
            }
        }

    } catch (const exception& e) {
        cerr << T("MSG_FATAL_ERROR") << e.what() << endl;
        return 1;
    }

    return 0;
}
