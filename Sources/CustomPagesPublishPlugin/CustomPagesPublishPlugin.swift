//
//  CustomPagesPublishPlugin.swift
//
//
//  Created by Stephen Hume on 2021-05-21.
//

import Foundation
import Publish
import Files
import Plot

public var pathsToMove: [Path: Path] = [:]
  
  // this is easy way to get rid of an index because Publish insists on HTML returned for indexes.

public extension Plugin {
  static var moveWebsitePages: Self {
    Plugin(name: "Moving custom files to final location") { context in
      do {
        let baseOutput = try context.outputFolder(at: "")
        try pathsToMove.forEach { (frompath: Path, target: Path) throws in
          let fromfile = try context.outputFile(at: frompath)
          if let fromFolder = fromfile.parent {
            let filedata = try fromfile.read()
            if !target.string.isEmpty {
              try baseOutput.createFile(at: target.string).write(filedata)
            }
            try fromfile.delete()
            if fromFolder.isEmpty() {
              let fromParent = fromFolder.parent
              try fromFolder.delete()
              if fromParent!.isEmpty() {
                try fromParent!.delete()  // could recurse but just need one level now.
              }
            }
          }
        }
      } catch {
        //        let error = error as! ShellOutError
        //        print(error.message)  // Prints STDERR
        //        print(error.output)  // Prints STDOUT
      }
    }
  }
}
public extension Path {
    func slashTerminated() -> Path {
        guard !string.isEmpty else {
            return ""
        }
        let separator = (string.last == "/" ? "" : "/")
        return "\(string)\(separator)"
    }
}
public extension PublishingStep {
  static func generateURISiteMap(excluding excludedPaths: Set<Path> = [],
                              indentedBy indentation: Indentation.Kind? = nil) -> Self {
      step(named: "Generate site map") { context in
          let generator = SiteMapGeneratorWithURI(
              excludedPaths: excludedPaths,
              indentation: indentation,
              context: context
          )

          try generator.generate()
      }
  }

struct SiteMapGeneratorWithURI <Site: Website> {
    let excludedPaths: Set<Path>
    let indentation: Indentation.Kind?
    let context: PublishingContext<Site>

    func generate() throws {
        let sections = context.sections.sorted {
            $0.id.rawValue < $1.id.rawValue
        }

        let pages = context.pages.values.sorted {
            $0.path < $1.path
        }

        let siteMap = makeSiteMapWithURI(for: sections, pages: pages, site: context.site)
        let xml = siteMap.render(indentedBy: indentation)
        let file = try context.createOutputFile(at: "sitemap.xml")
        try file.write(xml)
    }
  
  func shouldIncludePath(_ path: Path) -> Bool {
    !self.excludedPaths.contains(where: {
          path.string.hasPrefix($0.string)
      })
  }

  func makeSiteMapWithURI(for sections: [Section<Site>], pages: [Page], site: Site) -> SiteMap {
      SiteMap(
          .forEach(sections) { section in
              guard shouldIncludePath(section.path) else {
                  return .empty
              }

              return .group(
                  .url(
                    .loc(site.url(for: section.path.slashTerminated())),
                      .changefreq(.daily),
                      .priority(1.0),
                      .lastmod(max(
                          section.lastModified,
                          section.lastItemModificationDate ?? .distantPast
                      ))
                  ),
                  .forEach(section.items) { item in
                      guard shouldIncludePath(item.path) else {
                          return .empty
                      }

                      return .url(
                        .loc(site.url(for: item.path.slashTerminated())),
                          .changefreq(.monthly),
                          .priority(0.5),
                          .lastmod(item.lastModified)
                      )
                  }
              )
          },
          .forEach(pages) { page in
              guard shouldIncludePath(page.path) else {
                  return .empty
              }

              return .url(
                .loc(site.url(for: page.path.slashTerminated())),
                  .changefreq(.monthly),
                  .priority(0.5),
                  .lastmod(page.lastModified)
              )
          }
      )
  }
}
}
