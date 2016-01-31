struct DatabaseMigrator {
    func migrate(from: DataService, to: DataService, finish: Void -> Void) {
        from.allFeeds { oldFeeds in
            let oldArticles = oldFeeds.reduce([Article]()) { $0 + Array($1.articlesArray) }
            let oldEnclosures = oldArticles.reduce([Enclosure]()) { $0 + Array($1.enclosuresArray) }

            to.allFeeds { existingFeeds in
                let existingArticles = existingFeeds.reduce([Article]()) { $0 + Array($1.articlesArray) }
                let existingEnclosures = existingArticles.reduce([Enclosure]()) { $0 + Array($1.enclosuresArray) }

                let feedsToMigrate = oldFeeds.filter { !existingFeeds.contains($0) }
                let articlesToMigrate = oldArticles.filter { !existingArticles.contains($0) }
                let enclosuresToMigrate = oldEnclosures.filter { !existingEnclosures.contains($0) }

                var feedsDictionary: [Feed: Feed] = [:]
                var articlesDictionary: [Article: Article] = [:]

                var totalRemaining = feedsToMigrate.count + articlesToMigrate .count + enclosuresToMigrate.count
                let semaphore = dispatch_semaphore_create(0)

                let checkForCompleted = {
                    totalRemaining -= 1
                    if totalRemaining == 0 {
                        dispatch_semaphore_signal(semaphore)
                    }
                }

                for oldFeed in feedsToMigrate {
                    to.createFeed { newFeed in
                        self.migrateFeed(from: oldFeed, to: newFeed)
                        feedsDictionary[oldFeed] = newFeed
                        checkForCompleted()
                    }
                }

                for oldArticle in articlesToMigrate {
                    to.createArticle(feedsDictionary[oldArticle.feed!]) { newArticle in
                        self.migrateArticle(from: oldArticle, to: newArticle)
                        articlesDictionary[oldArticle] = newArticle
                        checkForCompleted()
                    }
                }

                for oldEnclosure in enclosuresToMigrate {
                    to.createEnclosure(articlesDictionary[oldEnclosure.article!]) { newEnclosure in
                        self.migrateEnclosure(from: oldEnclosure, to: newEnclosure)
                        checkForCompleted()
                    }
                }

                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
                finish()
            }
        }
    }

    private func migrateFeed(from oldFeed: Feed, to newFeed: Feed) {
        newFeed.title = oldFeed.title
        newFeed.url = oldFeed.url
        newFeed.summary = oldFeed.summary
        newFeed.query = oldFeed.query
        for tag in newFeed.tags {
            newFeed.removeTag(tag)
        }
        for tag in oldFeed.tags {
            newFeed.addTag(tag)
        }
        newFeed.waitPeriod = oldFeed.waitPeriod
        newFeed.remainingWait = oldFeed.remainingWait
        newFeed.image = oldFeed.image
    }

    private func migrateArticle(from oldArticle: Article, to newArticle: Article) {
        newArticle.title = oldArticle.title
        newArticle.link = oldArticle.link
        newArticle.summary = oldArticle.summary
        newArticle.author = oldArticle.author
        newArticle.published = oldArticle.published
        newArticle.updatedAt = oldArticle.updatedAt
        newArticle.identifier = oldArticle.identifier
        newArticle.content = oldArticle.content
        if oldArticle.estimatedReadingTime > 0 {
            newArticle.estimatedReadingTime = oldArticle.estimatedReadingTime
        } else {
            newArticle.estimatedReadingTime = estimateReadingTime(oldArticle.content)
        }
        newArticle.read = oldArticle.read

        for flag in newArticle.flags {
            newArticle.removeFlag(flag)
        }
        for flag in oldArticle.flags {
            newArticle.addFlag(flag)
        }
    }

    private func migrateEnclosure(from oldEnclosure: Enclosure, to newEnclosure: Enclosure) {
        newEnclosure.url = oldEnclosure.url
        newEnclosure.kind = oldEnclosure.kind
    }
}
